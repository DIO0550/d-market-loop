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
  # processing/ にファイルがあるか、todo/ にファイルがあれば残タスクあり
  ls "$TASKS_DIR"/processing/*.md &>/dev/null && return 0
  ls "$TASKS_DIR"/todo/*.md &>/dev/null && return 0
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
