#!/bin/bash
# PreToolUse hook for task-loop
# task-loop-config.json の allowedCommands に基づいて Bash コマンドを自動許可する

CONFIG_FILE="task-loop-config.json"

# stdin から hook input を読み取る
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Bash ツール以外は関与しない
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# 設定ファイルが無ければ関与しない
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$COMMAND" ]; then
  exit 0
fi

# allowedCommands を読み取り、前方一致で許可判定
ALLOWED=$(jq -r '.allowedCommands // [] | .[]' "$CONFIG_FILE" 2>/dev/null)

while IFS= read -r allowed_cmd; do
  [ -z "$allowed_cmd" ] && continue
  # 前方一致: "git commit" は "git commit -m 'msg'" にマッチ
  if [[ "$COMMAND" == "$allowed_cmd" || "$COMMAND" == "$allowed_cmd "* ]]; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: "task-loop-config.json の allowedCommands で許可済み"
      }
    }'
    exit 0
  fi
done <<< "$ALLOWED"

# マッチしなければ通常の権限システムに委ねる
exit 0
