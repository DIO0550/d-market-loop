#!/bin/bash
# PostCompact hook for task-loop
# コンパクション後にエージェントが再読込すべきファイルを指示する

echo "## コンパクション後の再読込指示"
echo ""
echo "コンテキストが圧縮されました。以下のファイルを読み込んで現在の状態を復元してください。"
echo ""

# 1. 設定ファイル
CONFIG_FILE="task-loop-config.json"
if [ -f "$CONFIG_FILE" ]; then
  echo "### 1. 設定ファイル"
  echo "- \`$CONFIG_FILE\` を読み込んで、ループの設定（baseBranch, reviewer, mergeStrategy 等）を把握してください。"
  echo ""
fi

# 2. タスクダッシュボード（Task.md）
PLAN_FILE="Task.md"
if [ -f "$PLAN_FILE" ]; then
  echo "### 2. タスクダッシュボード"
  echo "- \`$PLAN_FILE\` を読み込んで、プロジェクトのContext（Tech Stack, Architecture, Constraints, Shared Context, Notes）とカンバンの現在状態を把握してください。"
  echo ""
fi

# 3. 状態ファイル
STATE_FILE="task-loop-state.json"
if [ -f "$STATE_FILE" ]; then
  echo "### 3. 実行状態"
  echo "- \`$STATE_FILE\` を読み込んで、完了済み/失敗/進行中のタスク状態を把握してください。"
  echo ""
fi

# 4. 処理中のタスクファイル
TASKS_DIR="tasks"
if [ -d "$TASKS_DIR/processing" ]; then
  PROCESSING_FILES=$(find "$TASKS_DIR/processing" -name "*.md" -type f 2>/dev/null)
  if [ -n "$PROCESSING_FILES" ]; then
    echo "### 4. 処理中のタスク"
    for f in $PROCESSING_FILES; do
      echo "- \`$f\` を読み込んで、現在処理中のタスクの内容と進捗を把握してください。"
    done
    echo ""
  fi
fi

# 5. 現在のブランチとPR状態
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$CURRENT_BRANCH" ]; then
  echo "### 5. Git状態"
  echo "- 現在のブランチ: \`$CURRENT_BRANCH\`"

  PR_NUMBER_FILE="$TASKS_DIR/processing/.pr_number"
  if [ -f "$PR_NUMBER_FILE" ]; then
    PR_NUMBER=$(cat "$PR_NUMBER_FILE")
    echo "- 処理中のPR番号: #$PR_NUMBER"
    echo "- \`gh pr view $PR_NUMBER\` でPRの状態を確認してください。"
  fi
  echo ""
fi

echo "上記のファイルを読み込んだ上で、中断された作業を適切なステップから再開してください。"
