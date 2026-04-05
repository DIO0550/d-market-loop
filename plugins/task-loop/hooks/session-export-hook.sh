#!/bin/bash
# Stop hook: セッション終了時にセッションログのサマリーを生成する
# processing/ のタスクファイルのfrontmatterを元に、最新のセッション情報を記録する

CONFIG_FILE="task-loop-config.json"

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

TASKS_DIR=$(read_config "tasksDir" "tasks")
LOGS_DIR=$(read_config "sessionLogsDir" "session-logs")

# session-logs ディレクトリがなければ作成
mkdir -p "$LOGS_DIR"

# processing/ のタスクファイルを探す（直近処理中 or 直前に完了したもの）
CURRENT_TASK_FILE=$(ls "$TASKS_DIR"/processing/*.md 2>/dev/null | head -1)

# processing が空なら done/ の最新ファイルを使う
if [ -z "$CURRENT_TASK_FILE" ]; then
  CURRENT_TASK_FILE=$(ls -t "$TASKS_DIR"/done/*.md 2>/dev/null | head -1)
fi

if [ -z "$CURRENT_TASK_FILE" ]; then
  exit 0
fi

CURRENT_TASK=$(basename "$CURRENT_TASK_FILE")

# frontmatter から情報を取得（簡易パース）
extract_frontmatter() {
  local file="$1"
  local key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${key}:" | sed "s/^${key}:[[:space:]]*//" | tr -d '"'
}

TASK_BRANCH=$(extract_frontmatter "$CURRENT_TASK_FILE" "branch")
TASK_PR=$(extract_frontmatter "$CURRENT_TASK_FILE" "prUrl")
TASK_PR_NUM=$(extract_frontmatter "$CURRENT_TASK_FILE" "prNumber")

# フォルダでステータスを判定
TASK_STATUS="unknown"
case "$CURRENT_TASK_FILE" in
  *"/processing/"*) TASK_STATUS="in_progress" ;;
  *"/done/"*)       TASK_STATUS="completed" ;;
  *"/failed/"*)     TASK_STATUS="failed" ;;
esac

# カウンタはフォルダ内のファイル数で算出
TASKS_COMPLETED=$(ls "$TASKS_DIR"/done/*.md 2>/dev/null | wc -l | tr -d ' ')
TASKS_FAILED=$(ls "$TASKS_DIR"/failed/*.md 2>/dev/null | wc -l | tr -d ' ')

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
