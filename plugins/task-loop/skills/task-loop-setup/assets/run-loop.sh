#!/bin/bash
set -euo pipefail

TASKS_DIR="${TASKS_DIR:-tasks}"

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

while true; do
  if ! has_remaining_tasks; then
    echo "全タスクが処理済みです"
    break
  fi

  claude -p "/task-loop-run を実行してください。maxTasks=1 で1タスクだけ処理してください。" --allowedTools "Bash(git:*),Bash(gh:*),Read,Write,Edit,Glob,Grep"
done
