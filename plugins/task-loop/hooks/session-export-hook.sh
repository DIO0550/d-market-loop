#!/bin/bash
# Stop hook: セッション終了時にセッションログのサマリーを生成する
# task-loop-state.json の情報を元に、最新のセッション情報を記録する

CONFIG_FILE="task-loop-config.json"
STATE_FILE="task-loop-state.json"

# --- 設定読み込み ---
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

LOGS_DIR=$(read_config "sessionLogsDir" "session-logs")

# session-logs ディレクトリがなければ作成
mkdir -p "$LOGS_DIR"

# state.json が存在しない場合はスキップ
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# 現在処理中 or 直近完了のタスクを特定
CURRENT_TASK=$(jq -r '
  .tasks | to_entries |
  sort_by(.value.startedAt) | reverse |
  .[0] | .key // empty
' "$STATE_FILE" 2>/dev/null)

if [ -z "$CURRENT_TASK" ]; then
  exit 0
fi

TASK_STATUS=$(jq -r ".tasks[\"$CURRENT_TASK\"].status // empty" "$STATE_FILE" 2>/dev/null)
TASK_BRANCH=$(jq -r ".tasks[\"$CURRENT_TASK\"].branch // empty" "$STATE_FILE" 2>/dev/null)
TASK_PR=$(jq -r ".tasks[\"$CURRENT_TASK\"].prUrl // empty" "$STATE_FILE" 2>/dev/null)
TASK_PR_NUM=$(jq -r ".tasks[\"$CURRENT_TASK\"].prNumber // empty" "$STATE_FILE" 2>/dev/null)
TASKS_COMPLETED=$(jq -r '.tasksCompleted // 0' "$STATE_FILE" 2>/dev/null)
TASKS_FAILED=$(jq -r '.tasksFailed // 0' "$STATE_FILE" 2>/dev/null)

TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
TASK_NAME="${CURRENT_TASK%.md}"
OUTPUT_FILE="${LOGS_DIR}/${TIMESTAMP}_${TASK_NAME}.md"

# レポート生成
cat > "$OUTPUT_FILE" << EOF
---
generatedAt: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
task: "${CURRENT_TASK}"
status: "${TASK_STATUS}"
branch: "${TASK_BRANCH}"
---

# Session Log: ${TASK_NAME}

## 状態
- **タスク**: ${CURRENT_TASK}
- **ステータス**: ${TASK_STATUS}
- **ブランチ**: ${TASK_BRANCH}
- **PR**: ${TASK_PR:-なし}

## 全体進捗
- 完了: ${TASKS_COMPLETED}
- 失敗: ${TASKS_FAILED}

## 直近のコミット
$(git log --oneline -5 2>/dev/null || echo "（取得できませんでした）")

## 変更ファイル（ワーキングツリー）
$(git diff --name-only 2>/dev/null || echo "（なし）")
$(git diff --cached --name-only 2>/dev/null | sed 's/^/[staged] /' || true)
EOF

echo "Session log saved: ${OUTPUT_FILE}" >&2
