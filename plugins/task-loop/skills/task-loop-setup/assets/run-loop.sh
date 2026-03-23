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

# --- レビュー結果をポーリング ---
# 戻り値: "APPROVED", "CHANGES_REQUESTED", "TIMEOUT", "NO_PR"
poll_review() {
  local pr_number="$1"

  if [ -z "$pr_number" ]; then
    echo "NO_PR"
    return
  fi

  local max_wait_seconds=$((REVIEW_MAX_WAIT * 60))
  local elapsed=0

  echo "PR #${pr_number} のレビュー待ち開始（間隔: ${REVIEW_POLL_INTERVAL}秒、上限: ${REVIEW_MAX_WAIT}分）"

  while [ "$elapsed" -lt "$max_wait_seconds" ]; do
    local review_json
    review_json=$(gh pr view "$pr_number" --json reviews,latestReviews,reviewDecision 2>/dev/null || echo "{}")

    local decision
    decision=$(echo "$review_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    decision = data.get('reviewDecision', '')
    if decision:
        print(decision)
        sys.exit(0)
    # reviewDecision が空でも latestReviews に CHANGES_REQUESTED があるか確認
    for review in data.get('latestReviews', []):
        state = review.get('state', '')
        if state == 'APPROVED':
            print('APPROVED')
            sys.exit(0)
        if state == 'CHANGES_REQUESTED':
            print('CHANGES_REQUESTED')
            sys.exit(0)
    # レビューコメントに指摘が含まれるかチェック
    for review in data.get('latestReviews', []):
        body = review.get('body', '')
        if body and len(body.strip()) > 0:
            print('CHANGES_REQUESTED')
            sys.exit(0)
    print('')
except:
    print('')
" 2>/dev/null)

    case "$decision" in
      APPROVED)
        echo "レビュー結果: APPROVED"
        echo "APPROVED"
        return
        ;;
      CHANGES_REQUESTED)
        echo "レビュー結果: CHANGES_REQUESTED"
        echo "CHANGES_REQUESTED"
        return
        ;;
    esac

    echo "  レビュー待機中... (${elapsed}/${max_wait_seconds}秒)"
    sleep "$REVIEW_POLL_INTERVAL"
    elapsed=$((elapsed + REVIEW_POLL_INTERVAL))
  done

  echo "レビュータイムアウト（${REVIEW_MAX_WAIT}分経過）"
  echo "TIMEOUT"
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
    RESULT=$(poll_review "$PR_NUMBER")
    # poll_review は複数行出力する（ログ + 最終行が結果）
    REVIEW_STATUS=$(echo "$RESULT" | tail -1)

    case "$REVIEW_STATUS" in
      APPROVED)
        # --- Phase 3a: マージ ---
        echo "=== Phase: merge ==="
        MERGE_PROMPT="${PROMPT_BASE}

## 実行モード: merge

PR #${PR_NUMBER} がAPPROVEDされました。
Steps 7〜8（マージ、状態更新）を実行してください。
マージ後、タスクファイルを done/ に移動し、状態を更新して終了してください。"

        claude -p "$MERGE_PROMPT" --allowedTools "$ALLOWED_TOOLS"
        break
        ;;

      CHANGES_REQUESTED)
        FIX_COUNT=$((FIX_COUNT + 1))

        if [ "$FIX_COUNT" -gt "$MAX_FIX_ITERATIONS" ]; then
          echo "修正上限（${MAX_FIX_ITERATIONS}回）に達しました。手動対応が必要です。"
          # エラー処理をAIに委譲
          ERROR_PROMPT="${PROMPT_BASE}

## 実行モード: error

PR #${PR_NUMBER} のレビュー修正が上限（${MAX_FIX_ITERATIONS}回）に達しました。
タスクの状態を \`needs_manual_review\` に更新し、エラーリカバリーの手順に従って処理してください。"

          claude -p "$ERROR_PROMPT" --allowedTools "$ALLOWED_TOOLS"
          break
        fi

        # --- Phase 3b: 修正 ---
        echo "=== Phase: fix (${FIX_COUNT}/${MAX_FIX_ITERATIONS}) ==="
        FIX_PROMPT="${PROMPT_BASE}

## 実行モード: fix

PR #${PR_NUMBER} にレビュー指摘があります（修正回数: ${FIX_COUNT}/${MAX_FIX_ITERATIONS}）。
Step 6（レビュー指摘修正）を実行してください。
修正をコミット・プッシュしたら、レビュー待ちには入らず終了してください。
Task.md の Processing エントリの Step は \`reviewing\` に更新してから終了してください。"

        claude -p "$FIX_PROMPT" --allowedTools "$ALLOWED_TOOLS"
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
