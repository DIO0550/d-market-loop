#!/bin/bash
# PostCompact hook for task-loop
# コンパクション後に最初のプロンプト（指示書）を再注入する

INSTRUCTIONS_FILE="task-loop-instructions.md"

if [ -f "$INSTRUCTIONS_FILE" ]; then
  cat "$INSTRUCTIONS_FILE"
fi
