#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS_DIR="${TASKS_DIR:-tasks}"
INSTRUCTIONS_FILE="${SCRIPT_DIR}/task-loop-instructions.md"

if [ ! -f "$INSTRUCTIONS_FILE" ]; then
  echo "Error: 指示書が見つかりません: $INSTRUCTIONS_FILE" >&2
  exit 1
fi

has_remaining_tasks() {
  for file in "$TASKS_DIR"/*.md; do
    [ -f "$file" ] || continue
    local status
    status=$(sed -n '/^---$/,/^---$/{ /^status:/{ s/^status:[[:space:]]*//; p; } }' "$file")
    if [ -z "$status" ] || [ "$status" = "pending" ] || [ "$status" = "in_progress" ]; then
      return 0
    fi
  done
  return 1
}

PROMPT="$(cat "$INSTRUCTIONS_FILE")"

while true; do
  if ! has_remaining_tasks; then
    echo "全タスクが処理済みです"
    break
  fi

  claude -p "$PROMPT" --allowedTools "Bash(git:*),Bash(gh:*),Read,Write,Edit,Glob,Grep"
done
