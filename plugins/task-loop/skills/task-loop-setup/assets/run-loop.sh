#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS_DIR="${TASKS_DIR:-tasks}"
STATE_FILE="${STATE_FILE:-task-loop-state.json}"
CONFIG_FILE="${CONFIG_FILE:-task-loop-config.json}"
INSTRUCTIONS_FILE="${SCRIPT_DIR}/task-loop-instructions.md"

if [ ! -f "$INSTRUCTIONS_FILE" ]; then
  echo "Error: 指示書が見つかりません: $INSTRUCTIONS_FILE" >&2
  exit 1
fi

# --- 設定読み込み ---
read_config() {
  local key="$1"
  local default="$2"
  if [ -f "$CONFIG_FILE" ]; then
    local val
    val=$(python3 -c "
import json, sys
try:
    cfg = json.load(open('$CONFIG_FILE'))
    print(cfg.get('$key', '$default'))
except: print('$default')
" 2>/dev/null)
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

REVIEW_POLL_INTERVAL=$(read_config "reviewPollIntervalSeconds" "30")
REVIEW_MAX_WAIT=$(read_config "reviewMaxWaitMinutes" "30")
AUTO_MERGE_WITHOUT_REVIEW=$(read_config "autoMergeWithoutReview" "false")
MAX_FIX_ITERATIONS=$(read_config "maxFixIterations" "3")
REVIEWER=$(read_config "reviewer" "copilot")

# --- タスク残存チェック ---
has_remaining_tasks() {
  ls "$TASKS_DIR"/processing/*.md &>/dev/null && return 0
  ls "$TASKS_DIR"/todo/*.md &>/dev/null && return 0
  return 1
}

# --- state.json からPR番号を取得 ---
get_pr_number_from_state() {
  if [ ! -f "$STATE_FILE" ]; then
    echo ""
    return
  fi
  python3 -c "
import json, sys
try:
    state = json.load(open('$STATE_FILE'))
    for name, task in state.get('tasks', {}).items():
        if task.get('status') == 'in_progress' and task.get('prNumber'):
            print(task['prNumber'])
            sys.exit(0)
    print('')
except: print('')
" 2>/dev/null
}

# --- processing中のタスクがあるかチェック ---
has_processing_task() {
  ls "$TASKS_DIR"/processing/*.md &>/dev/null
}

# --- レビュー完了をポーリング ---
# Copilotのレビューが完了したか（レビューを提出したか）を検知する。
# 戻り値（最終行）:
#   "REVIEWED"  - レビュアーがレビューを提出済み
#   "TIMEOUT"   - 制限時間超過
#   "NO_PR"     - PR番号が不明
poll_review() {
  local pr_number="$1"
  local baseline_review_count="$2"  # ポーリング開始時点のレビュー数

  if [ -z "$pr_number" ]; then
    echo "NO_PR"
    return
  fi

  local max_wait_seconds=$((REVIEW_MAX_WAIT * 60))
  local elapsed=0

  echo "PR #${pr_number} のレビュー待ち開始（間隔: ${REVIEW_POLL_INTERVAL}秒、上限: ${REVIEW_MAX_WAIT}分）"

  while [ "$elapsed" -lt "$max_wait_seconds" ]; do
    # latestReviews でレビュー提出済みかチェック
    local current_review_count
    current_review_count=$(gh pr view "$pr_number" --json latestReviews --jq '.latestReviews | length' 2>/dev/null || echo "0")

    if [ "$current_review_count" -gt "$baseline_review_count" ]; then
      echo "レビュー完了を検出（レビュー数: ${baseline_review_count} → ${current_review_count}）"
      echo "REVIEWED"
      return
    fi

    echo "  レビュー待機中... (${elapsed}/${max_wait_seconds}秒)"
    sleep "$REVIEW_POLL_INTERVAL"
    elapsed=$((elapsed + REVIEW_POLL_INTERVAL))
  done

  echo "レビュータイムアウト（${REVIEW_MAX_WAIT}分経過）"
  echo "TIMEOUT"
}

# --- 現在のレビュー数を取得 ---
get_review_count() {
  local pr_number="$1"
  gh pr view "$pr_number" --json latestReviews --jq '.latestReviews | length' 2>/dev/null || echo "0"
}

PROMPT_BASE="$(cat "$INSTRUCTIONS_FILE")"
ALLOWED_TOOLS="Bash(git:*),Bash(gh:*),Read,Write,Edit,Glob,Grep"

while true; do
  if ! has_remaining_tasks; then
    echo "全タスクが処理済みです"
    break
  fi

  # --- Phase 1: processing中のタスクがある場合、中断復帰チェック ---
  PR_NUMBER=""
  if has_processing_task; then
    PR_NUMBER=$(get_pr_number_from_state)
  fi

  if [ -n "$PR_NUMBER" ] && has_processing_task; then
    # PR作成済みのprocessingタスクがある → レビューフローへ
    echo "PR #${PR_NUMBER} が存在する処理中タスクを検出。レビューフローに入ります。"
  else
    # --- Phase 1: 実装 + PR作成 ---
    echo "=== Phase: implement ==="
    IMPLEMENT_PROMPT="${PROMPT_BASE}

## 実行モード: implement

Steps 1〜4（タスク初期化、実装、コミット、PR作成）までを実行してください。
PR作成後、レビュー待ちには入らず終了してください。
Task.md の Processing エントリの Step は \`reviewing\` に更新してから終了してください。"

    claude -p "$IMPLEMENT_PROMPT" --allowedTools "$ALLOWED_TOOLS"

    # PR番号を取得
    PR_NUMBER=$(get_pr_number_from_state)

    if [ -z "$PR_NUMBER" ]; then
      echo "Warning: PR番号が取得できませんでした。次のタスクに進みます。"
      continue
    fi
  fi

  # --- Phase 2: レビューポーリング (shell側) ---
  FIX_COUNT=0

  while true; do
    echo "=== Phase: poll ==="

    # ポーリング開始時点のレビュー数をベースラインとして記録
    BASELINE_REVIEW_COUNT=$(get_review_count "$PR_NUMBER")

    RESULT=$(poll_review "$PR_NUMBER" "$BASELINE_REVIEW_COUNT")
    # poll_review は複数行出力する（ログ + 最終行が結果）
    REVIEW_STATUS=$(echo "$RESULT" | tail -1)

    case "$REVIEW_STATUS" in
      REVIEWED)
        # レビューが提出された → AIにコメント内容を分析させる
        echo "=== Phase: review-check ==="
        REVIEW_CHECK_PROMPT="${PROMPT_BASE}

## 実行モード: review-check

PR #${PR_NUMBER} のレビューが完了しました。

以下の手順で処理してください:

1. PRのレビューコメントを取得する:
   \`\`\`bash
   gh api repos/{owner}/{repo}/pulls/${PR_NUMBER}/comments
   gh api repos/{owner}/{repo}/pulls/${PR_NUMBER}/reviews
   \`\`\`
2. コメント内容を分析し、**修正が必要な指摘があるか**を判断する
3. 判断結果に応じて:
   - **指摘なし**（情報提供のみ、褒めるコメント、軽微な提案のみ等）:
     → Steps 7〜8（マージ、状態更新）を実行して終了
   - **指摘あり**（コード修正が必要な指摘、バグの指摘等）:
     → Step 6（レビュー指摘修正）を実行
     → 修正をコミット・プッシュしたら、レビュー待ちには入らず終了
     → Task.md の Processing エントリの Step は \`reviewing\` に更新してから終了

修正回数: ${FIX_COUNT}/${MAX_FIX_ITERATIONS}"

        claude -p "$REVIEW_CHECK_PROMPT" --allowedTools "$ALLOWED_TOOLS"

        # AIの処理結果を確認: タスクが done/ に移動していればマージ完了
        if ! has_processing_task; then
          echo "タスクがマージされました。"
          break
        fi

        # まだ processing にある = 修正して再レビュー待ち
        FIX_COUNT=$((FIX_COUNT + 1))

        if [ "$FIX_COUNT" -gt "$MAX_FIX_ITERATIONS" ]; then
          echo "修正上限（${MAX_FIX_ITERATIONS}回）に達しました。手動対応が必要です。"
          ERROR_PROMPT="${PROMPT_BASE}

## 実行モード: error

PR #${PR_NUMBER} のレビュー修正が上限（${MAX_FIX_ITERATIONS}回）に達しました。
タスクの状態を \`needs_manual_review\` に更新し、エラーリカバリーの手順に従って処理してください。"

          claude -p "$ERROR_PROMPT" --allowedTools "$ALLOWED_TOOLS"
          break
        fi
        # ループの先頭に戻って再ポーリング
        ;;

      TIMEOUT)
        if [ "$AUTO_MERGE_WITHOUT_REVIEW" = "true" ]; then
          echo "タイムアウト: autoMergeWithoutReview=true のため自動マージします。"
          MERGE_PROMPT="${PROMPT_BASE}

## 実行モード: merge

PR #${PR_NUMBER} のレビューがタイムアウトしました。autoMergeWithoutReview が有効なため、マージを実行します。
Steps 7〜8（マージ、状態更新）を実行してください。"

          claude -p "$MERGE_PROMPT" --allowedTools "$ALLOWED_TOOLS"
        else
          echo "タイムアウト: レビューが得られませんでした。次のタスクに進みます。"
          TIMEOUT_PROMPT="${PROMPT_BASE}

## 実行モード: error

PR #${PR_NUMBER} のレビューがタイムアウトしました（${REVIEW_MAX_WAIT}分）。
autoMergeWithoutReview=false のため、ユーザーに通知して次のタスクへ進む処理を行ってください。
エラーリカバリーの手順に従ってタスクの状態を更新してください。"

          claude -p "$TIMEOUT_PROMPT" --allowedTools "$ALLOWED_TOOLS"
        fi
        break
        ;;

      NO_PR)
        echo "Error: PR番号が取得できませんでした。"
        break
        ;;
    esac
  done
done
