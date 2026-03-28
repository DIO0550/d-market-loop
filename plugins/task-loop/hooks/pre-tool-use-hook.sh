#!/bin/bash
# PreToolUse hook for task-loop
# git/gh コマンドを常に許可し、
# task-loop-config.json の allowedCommands に基づいて追加コマンドを自動許可する

CONFIG_FILE="task-loop-config.json"

# stdin から hook input を読み取る
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Bash ツール以外は関与しない
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$COMMAND" ]; then
  exit 0
fi

allow() {
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "task-loop hook: 許可済みコマンド"
    }
  }'
  exit 0
}

# コマンドの先頭トークンを取得
CMD_BIN=$(echo "$COMMAND" | awk '{print $1}')

# git / gh は常に許可
case "$CMD_BIN" in
  git|gh) allow ;;
esac

# 設定ファイルが無ければここで終了（通常の権限システムに委ねる）
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

# allowedCommands を読み取り、完全一致で許可判定
ALLOWED=$(jq -r '.allowedCommands // [] | .[]' "$CONFIG_FILE" 2>/dev/null)

while IFS= read -r allowed_cmd; do
  [ -z "$allowed_cmd" ] && continue
  if [ "$COMMAND" = "$allowed_cmd" ]; then
    allow
  fi
done <<< "$ALLOWED"

# マッチしなければ通常の権限システムに委ねる
exit 0
