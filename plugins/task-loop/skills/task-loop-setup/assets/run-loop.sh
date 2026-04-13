#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS_DIR="${TASKS_DIR:-tasks}"
CONFIG_FILE="${CONFIG_FILE:-task-loop-config.json}"
PR_NUMBER_FILE="${TASKS_DIR}/processing/.pr_number"
INSTRUCTIONS_FILE="${SCRIPT_DIR}/task-loop-instructions.md"
SESSION_LOGS_DIR="${SESSION_LOGS_DIR:-session-logs}"

if [ ! -f "$INSTRUCTIONS_FILE" ]; then
  echo "Error: 指示書が見つかりません: $INSTRUCTIONS_FILE" >&2
  exit 1
fi

# --- 設定読み込み (jq) ---
read_config() {
  local key="$1"
  local default="$2"
  if [ -f "$CONFIG_FILE" ]; then
    local val
    val=$(jq -r ".${key} // empty" "$CONFIG_FILE" 2>/dev/null)
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

REVIEW_POLL_INTERVAL=$(read_config "reviewPollIntervalSeconds" "30")
REVIEW_MAX_WAIT=$(read_config "reviewMaxWaitMinutes" "30")
AUTO_MERGE_WITHOUT_REVIEW=$(read_config "autoMergeWithoutReview" "false")
MAX_FIX_ITERATIONS=$(read_config "maxFixIterations" "3")
REVIEWER=$(read_config "reviewer" "copilot-pull-request-reviewer")
SESSION_LOGS_DIR=$(read_config "sessionLogsDir" "$SESSION_LOGS_DIR")

# --- セッションログ ---
mkdir -p "$SESSION_LOGS_DIR"

run_claude_session() {
  local mode="$1"
  local prompt="$2"
  local task_name="${3:-unknown}"
  local timestamp
  timestamp=$(date +"%Y-%m-%d_%H%M%S")
  local log_file="${SESSION_LOGS_DIR}/${timestamp}_${mode}_${task_name}.md"

  echo ""
  echo ">>> Claude Session Start: ${mode} / ${task_name}"
  echo "    Log: ${log_file}"
  echo ""

  {
    echo "---"
    echo "mode: \"${mode}\""
    echo "task: \"${task_name}\""
    echo "startedAt: \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\""
    echo "---"
    echo ""
    echo "# Session Output: ${mode} / ${task_name}"
    echo ""
    echo '```'
  } > "$log_file"

  # stream-json でストリーミング出力を取得し、ログには生JSON、ターミナルには jq で整形した要約を流す
  claude -p "$prompt" --allowedTools "$ALLOWED_TOOLS" \
      --output-format stream-json --verbose 2>&1 \
    | tee -a "$log_file" \
    | while IFS= read -r line; do
        echo "$line" | jq -r '
          if .type == "assistant" then
            (.message.content[]? |
              if .type == "text" then "  " + .text
              elif .type == "tool_use" then "  [tool] " + .name + " " + (.input | tostring | .[0:120])
              else empty end)
          elif .type == "user" then
            (.message.content[]? |
              if .type == "tool_result" then "  [result]"
              else empty end)
          elif .type == "result" then
            "  [done] " + (.subtype // "ok")
          else empty end' 2>/dev/null || true
      done
  local exit_code=${PIPESTATUS[0]}

  {
    echo '```'
    echo ""
    echo "endedAt: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "exitCode: ${exit_code}"
  } >> "$log_file"

  echo ""
  echo "<<< Claude Session End (exit: ${exit_code})"
  echo ""

  return $exit_code
}

# --- タスク残存チェック ---
has_remaining_tasks() {
  ls "$TASKS_DIR"/processing/*.md &>/dev/null && return 0
  ls "$TASKS_DIR"/todo/*.md &>/dev/null && return 0
  return 1
}

# --- 現在のタスク名を取得 ---
get_current_task_name() {
  local task_file
  task_file=$(ls "$TASKS_DIR"/processing/*.md 2>/dev/null | head -1)
  if [ -z "$task_file" ]; then
    task_file=$(ls "$TASKS_DIR"/todo/*.md 2>/dev/null | head -1)
  fi
  if [ -n "$task_file" ]; then
    basename "$task_file" .md
  else
    echo "unknown"
  fi
}

# --- processing中のタスクがあるかチェック ---
has_processing_task() {
  ls "$TASKS_DIR"/processing/*.md &>/dev/null
}

# --- PR番号の読み書き ---
save_pr_number() {
  echo "$1" > "$PR_NUMBER_FILE"
}

read_pr_number() {
  if [ -f "$PR_NUMBER_FILE" ]; then
    cat "$PR_NUMBER_FILE"
  else
    echo ""
  fi
}

clean_pr_number() {
  rm -f "$PR_NUMBER_FILE"
}

# --- レビュー完了をポーリング ---
# PR の HEAD コミット SHA に対して REVIEWER のレビューが存在するかで判定する。
# これにより以下のケースが全て正しく動作する:
#   - 初回レビュー: HEAD はそのまま、レビューが来れば検出
#   - fix 後の再レビュー: push で HEAD が更新され、新 HEAD 上のレビューを待つ
#   - 途中再開: 現 HEAD を基準にするので古いレビューの誤検知がない
#   - race なし: baseline の概念自体が不要
#
# 引数:
#   $1 - PR番号
#
# 戻り値（stdout に status を返す、進捗ログは stderr へ）:
#   "REVIEWED"  - 現 HEAD に対するレビューが存在
#   "TIMEOUT"   - 制限時間超過
#   "NO_PR"     - PR番号が不明、または HEAD SHA 取得失敗
poll_review() {
  local pr_number="$1"

  if [ -z "$pr_number" ]; then
    echo "NO_PR"
    return
  fi

  local head_sha
  head_sha=$(gh pr view "$pr_number" --json headRefOid --jq '.headRefOid' 2>/dev/null)

  if [ -z "$head_sha" ]; then
    echo "NO_PR"
    return
  fi

  local max_wait_seconds=$((REVIEW_MAX_WAIT * 60))
  local elapsed=0

  echo "PR #${pr_number} のレビュー待ち開始（レビュアー: ${REVIEWER}、HEAD: ${head_sha:0:8}、間隔: ${REVIEW_POLL_INTERVAL}秒、上限: ${REVIEW_MAX_WAIT}分）" >&2

  while [ "$elapsed" -lt "$max_wait_seconds" ]; do
    # gh pr view (GraphQL) の author.login は "[bot]" サフィックスなしで REVIEWER 設定値と一致する
    # （REST API の user.login は "copilot-pull-request-reviewer[bot]" でサフィックスが付くので使えない）
    local review_state
    review_state=$(gh pr view "$pr_number" --json reviews \
      --jq "[.reviews[] | select(.author.login == \"${REVIEWER}\" and .commit.oid == \"${head_sha}\")] | last | .state // empty" 2>/dev/null || echo "")

    if [ -n "$review_state" ]; then
      echo "HEAD ${head_sha:0:8} 上のレビューを検出（${REVIEWER}: ${review_state}）" >&2
      echo "REVIEWED"
      return
    fi

    echo "  レビュー待機中... ${REVIEWER} が HEAD ${head_sha:0:8} をレビュー中 (${elapsed}/${max_wait_seconds}秒)" >&2
    sleep "$REVIEW_POLL_INTERVAL"
    elapsed=$((elapsed + REVIEW_POLL_INTERVAL))
  done

  echo "レビュータイムアウト（${REVIEW_MAX_WAIT}分経過）" >&2
  echo "TIMEOUT"
}

PROMPT_BASE="$(cat "$INSTRUCTIONS_FILE")"

# --- デフォルト許可コマンド（pre-tool-use-hook.sh.template と同じ） ---
DEFAULT_ALLOWED_COMMANDS=(
  "git status" "git add" "git commit" "git push" "git pull" "git fetch"
  "git checkout" "git switch" "git branch" "git diff" "git log"
  "git stash" "git merge" "git rebase"
  "gh pr create" "gh pr edit" "gh pr view" "gh pr merge" "gh pr list" "gh api" "gh auth status"
  "ls" "cat" "wc" "which" "command -v"
  "mkdir -p" "cp" "mv"
  "tsc --noEmit" "tsc -p" "eslint" "prettier --check" "vitest" "jest"
  "pnpm test" "pnpm run lint" "pnpm run build" "pnpm run typecheck" "pnpm run format"
)

# --- allowedTools の構築 ---
build_allowed_tools() {
  local tools=""
  # デフォルト許可コマンド
  for cmd in "${DEFAULT_ALLOWED_COMMANDS[@]}"; do
    [ -n "$tools" ] && tools="${tools},"
    tools="${tools}Bash(${cmd})"
  done
  # プロジェクト固有の許可コマンド
  if [ -f "$CONFIG_FILE" ]; then
    local cmds
    cmds=$(jq -r '.allowedCommands // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      tools="${tools},Bash(${cmd})"
    done <<< "$cmds"
  fi
  echo "${tools},Read,Write,Edit,Glob,Grep,TodoRead,TodoWrite"
}

ALLOWED_TOOLS="$(build_allowed_tools)"
echo "allowedTools: ${ALLOWED_TOOLS}"

# --- 許可コマンド一覧をプロンプトに注入 ---
build_allowed_commands_prompt() {
  echo ""
  echo "## 使用可能なコマンド"
  echo ""
  echo "以下のコマンドが実行許可されています:"
  echo ""
  for cmd in "${DEFAULT_ALLOWED_COMMANDS[@]}"; do
    echo "- \`${cmd}\`"
  done
  if [ -f "$CONFIG_FILE" ]; then
    local cmds
    cmds=$(jq -r '.allowedCommands // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      echo "- \`${cmd}\`"
    done <<< "$cmds"
  fi
  echo ""
  echo "上記以外のBashコマンドは使用できません。"
}

PROMPT_BASE="${PROMPT_BASE}
$(build_allowed_commands_prompt)"

while true; do
  if ! has_remaining_tasks; then
    echo "全タスクが処理済みです"
    break
  fi

  # --- Phase 1: processing中のタスクがある場合、中断復帰チェック ---
  PR_NUMBER=""
  if has_processing_task; then
    PR_NUMBER=$(read_pr_number)
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
**重要**: PR作成後、PR番号を \`${PR_NUMBER_FILE}\` に書き出してください。"

    run_claude_session "implement" "$IMPLEMENT_PROMPT" "$(get_current_task_name)"

    # PR番号を取得
    PR_NUMBER=$(read_pr_number)

    if [ -z "$PR_NUMBER" ]; then
      echo "Warning: PR番号が取得できませんでした。次のタスクに進みます。"
      continue
    fi
  fi

  # --- Phase 2: レビューポーリング (shell側) ---
  FIX_COUNT=0

  while true; do
    echo "=== Phase: poll ==="
    # 進捗ログは stderr、stdout にはステータスのみ ("REVIEWED" / "TIMEOUT" / "NO_PR")
    REVIEW_STATUS=$(poll_review "$PR_NUMBER")

    case "$REVIEW_STATUS" in
      REVIEWED)
        # レビューが提出された → AIにコメント内容を分析させる
        echo "=== Phase: review-check ==="
        REVIEW_CHECK_PROMPT="${PROMPT_BASE}

## 実行モード: review-check

PR #${PR_NUMBER} のレビューが完了しました。

以下の手順で処理してください:

1. 未解決のレビュースレッドを確認する:
   \`\`\`bash
   gh api graphql -f query='
     query(\$owner: String!, \$repo: String!, \$number: Int!) {
       repository(owner: \$owner, name: \$repo) {
         pullRequest(number: \$number) {
           reviewThreads(first: 100) {
             nodes {
               id
               isResolved
               comments(first: 10) {
                 nodes { body path line author { login } }
               }
             }
           }
         }
       }
     }
   ' -f owner='{owner}' -f repo='{repo}' -F number=${PR_NUMBER}
   \`\`\`
   ※ {owner} と {repo} は \`git remote get-url origin\` から取得すること
2. 未解決スレッド（\`isResolved: false\`）の有無で判断する:
   - **未解決スレッドなし**:
     → Steps 7〜8（マージ、状態更新）を実行して終了
   - **未解決スレッドあり**:
     → Step 6（レビュー指摘修正）の**全手順**を実行して終了
     → 修正 → コミット・プッシュ → スレッド解決 → 再レビュー依頼 まで**必ず全て実施**すること
     → 再レビュー依頼（\`gh pr edit --add-reviewer\`）を省略すると外部ループが次のレビューを永久に待ち続ける

修正回数: ${FIX_COUNT}/${MAX_FIX_ITERATIONS}"

        run_claude_session "review-check" "$REVIEW_CHECK_PROMPT" "$(get_current_task_name)"

        # AIの処理結果を確認: タスクが done/ に移動していればマージ完了
        if ! has_processing_task; then
          echo "タスクがマージされました。"
          clean_pr_number
          break
        fi

        # まだ processing にある = 修正して再レビュー待ち
        FIX_COUNT=$((FIX_COUNT + 1))

        if [ "$FIX_COUNT" -gt "$MAX_FIX_ITERATIONS" ]; then
          echo "修正上限（${MAX_FIX_ITERATIONS}回）に達しました。マージを試みてからfailedに記録します。"
          ERROR_PROMPT="${PROMPT_BASE}

## 実行モード: error

PR #${PR_NUMBER} のレビュー修正が上限（${MAX_FIX_ITERATIONS}回）に達しました。
ただし後続タスクのブロックを避けるため、**最終的にマージまで到達させる**ことを最優先とします。

以下の手順で処理してください:

1. **PR のマージを試みる**（Step 7: \`steps/merge.md\`）
   - mergeable なら \`gh pr merge\` で即マージする
   - マージコンフリクト等で失敗した場合のみリベース → 再マージを試みる
2. マージ結果にかかわらずタスクを \`{tasksDir}/failed/\` に移動し、frontmatter に以下を記録する:
   - \`error: \"fix_limit_exceeded\"\`
   - \`fixIterations: ${FIX_COUNT}\`
   - \`merged: true | false\`（マージ成否）
3. 状態更新のコミット（Step 8: \`steps/update-state.md\` と同等の処理）を push する
4. **\`stopOnError\` の値に関わらず、このセッションは正常終了すること**（次のタスクに進める必要があるため）

重要: タスクを failed に記録するのは構わないが、PR 自体は可能な限りマージを試みること。"

          run_claude_session "error" "$ERROR_PROMPT" "$(get_current_task_name)"
          clean_pr_number
          break
        fi
        # ループの先頭に戻って再ポーリング
        ;;

      TIMEOUT)
        if [ "$AUTO_MERGE_WITHOUT_REVIEW" = "true" ]; then
          echo "タイムアウト: autoMergeWithoutReview=true のため自動マージします。"
          MERGE_PROMPT="${PROMPT_BASE}

## 実行モード: review-check

PR #${PR_NUMBER} のレビューがタイムアウトしました。autoMergeWithoutReview が有効なため、マージを実行します。
Steps 7〜8（マージ、状態更新）を実行してください。"

          run_claude_session "merge" "$MERGE_PROMPT" "$(get_current_task_name)"
        else
          echo "タイムアウト: レビューが得られませんでした。次のタスクに進みます。"
          TIMEOUT_PROMPT="${PROMPT_BASE}

## 実行モード: error

PR #${PR_NUMBER} のレビューがタイムアウトしました（${REVIEW_MAX_WAIT}分）。
autoMergeWithoutReview=false のため、ユーザーに通知して次のタスクへ進む処理を行ってください。
エラーリカバリーの手順に従ってタスクの状態を更新してください。"

          run_claude_session "timeout-error" "$TIMEOUT_PROMPT" "$(get_current_task_name)"
        fi
        clean_pr_number
        break
        ;;

      NO_PR)
        echo "Error: PR番号が取得できませんでした。"
        clean_pr_number
        break
        ;;
    esac
  done
done
