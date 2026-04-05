#!/bin/bash
# Stop hook: セッションログ出力ディレクトリの確保
CONFIG_FILE="task-loop-config.json"

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
mkdir -p "$LOGS_DIR"
