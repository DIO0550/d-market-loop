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

# コマンドの先頭トークンを取得（例: "pnpm test" → "pnpm"）
CMD_BIN=$(echo "$COMMAND" | awk '{print $1}')

# allowedCommands を読み取る
ALLOWED=$(jq -r '.allowedCommands // [] | .[]' "$CONFIG_FILE" 2>/dev/null)

while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue

  # ワイルドカードパターン: "pnpm:*" → pnpm の全サブコマンドを許可
  if [[ "$pattern" == *":*" ]]; then
    ALLOWED_BIN="${pattern%%:*}"
    if [ "$CMD_BIN" = "$ALLOWED_BIN" ]; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow",
          permissionDecisionReason: "task-loop-config.json の allowedCommands で許可済み"
        }
      }'
      exit 0
    fi
  else
    # 完全一致パターン: "pnpm test" → そのコマンドだけ許可
    if [ "$COMMAND" = "$pattern" ]; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow",
          permissionDecisionReason: "task-loop-config.json の allowedCommands で許可済み"
        }
      }'
      exit 0
    fi
  fi
done <<< "$ALLOWED"

# マッチしなければ通常の権限システムに委ねる
exit 0
