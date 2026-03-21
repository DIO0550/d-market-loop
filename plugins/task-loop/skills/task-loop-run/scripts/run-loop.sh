#!/bin/bash
#
# run-loop.sh - Claude CLIを繰り返し起動してタスクを1つずつ処理する外部ループスクリプト
#
# 使い方:
#   ./run-loop.sh [オプション]
#
# オプション:
#   -n, --max-tasks NUM      最大タスク数（デフォルト: 無制限）
#   -t, --time-limit MIN     制限時間（分、デフォルト: 無制限）
#   -d, --tasks-dir DIR      タスクディレクトリ（デフォルト: tasks）
#   -p, --prompt PROMPT      Claude CLIに渡す追加プロンプト
#   -h, --help               ヘルプを表示
#

set -euo pipefail

# デフォルト値
MAX_TASKS=0
TIME_LIMIT=0
TASKS_DIR="tasks"
EXTRA_PROMPT=""
COMPLETED=0
START_TIME=$(date +%s)

usage() {
    cat <<'USAGE'
Usage: run-loop.sh [OPTIONS]

Claude CLIを繰り返し起動してタスクを1つずつ処理する。
各タスクは独立したClaudeセッションで処理される。

Options:
  -n, --max-tasks NUM      処理する最大タスク数（0 = 無制限）
  -t, --time-limit MIN     制限時間（分、0 = 無制限）
  -d, --tasks-dir DIR      タスクディレクトリ（デフォルト: tasks）
  -p, --prompt PROMPT      Claude CLIに渡す追加プロンプト
  -h, --help               このヘルプを表示

Examples:
  # 全タスクを処理
  ./run-loop.sh

  # 3タスクだけ処理
  ./run-loop.sh -n 3

  # 60分の制限時間付き
  ./run-loop.sh -t 60

  # カスタムタスクディレクトリ
  ./run-loop.sh -d my-tasks
USAGE
}

# 引数パース
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--max-tasks)
            MAX_TASKS="$2"
            shift 2
            ;;
        -t|--time-limit)
            TIME_LIMIT="$2"
            shift 2
            ;;
        -d|--tasks-dir)
            TASKS_DIR="$2"
            shift 2
            ;;
        -p|--prompt)
            EXTRA_PROMPT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: 不明なオプション: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# 前提条件チェック
if ! command -v claude &> /dev/null; then
    echo "Error: claude CLI が見つかりません" >&2
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI が見つかりません" >&2
    exit 1
fi

if [ ! -d "$TASKS_DIR" ]; then
    echo "Error: タスクディレクトリ '$TASKS_DIR' が見つかりません" >&2
    exit 1
fi

# pendingタスクがあるか確認する関数
has_pending_tasks() {
    for file in "$TASKS_DIR"/*.md; do
        [ -f "$file" ] || continue
        # frontmatterからstatusを取得
        local status
        status=$(sed -n '/^---$/,/^---$/{ /^status:/{ s/^status:[[:space:]]*//; p; } }' "$file")
        # statusが未設定、空、またはpendingなら未処理タスクあり
        if [ -z "$status" ] || [ "$status" = "pending" ]; then
            return 0
        fi
    done
    return 1
}

# 制限時間チェック
check_time_limit() {
    if [ "$TIME_LIMIT" -gt 0 ]; then
        local elapsed=$(( ($(date +%s) - START_TIME) / 60 ))
        if [ "$elapsed" -ge "$TIME_LIMIT" ]; then
            return 1
        fi
    fi
    return 0
}

echo "=== Task Loop 開始 ==="
echo "タスクディレクトリ: $TASKS_DIR"
[ "$MAX_TASKS" -gt 0 ] && echo "最大タスク数: $MAX_TASKS"
[ "$TIME_LIMIT" -gt 0 ] && echo "制限時間: ${TIME_LIMIT}分"
echo ""

# メインループ
while true; do
    # ループ条件チェック
    if ! has_pending_tasks; then
        echo "全タスクが処理済みです"
        break
    fi

    if [ "$MAX_TASKS" -gt 0 ] && [ "$COMPLETED" -ge "$MAX_TASKS" ]; then
        echo "最大タスク数 ($MAX_TASKS) に到達しました"
        break
    fi

    if ! check_time_limit; then
        echo "制限時間 (${TIME_LIMIT}分) を超過しました"
        break
    fi

    # Claude CLIを起動
    COMPLETED=$((COMPLETED + 1))
    echo "--- タスク #$COMPLETED を処理中 ---"

    PROMPT="/task-loop-run を実行してください。maxTasks=1 で1タスクだけ処理してください。"
    if [ -n "$EXTRA_PROMPT" ]; then
        PROMPT="$PROMPT $EXTRA_PROMPT"
    fi

    # Claude CLIを実行（非対話モード）
    if claude -p "$PROMPT" --allowedTools "Bash(git:*),Bash(gh:*),Read,Write,Edit,Glob,Grep"; then
        echo "タスク #$COMPLETED: 完了"
    else
        echo "タスク #$COMPLETED: Claude CLIがエラーで終了しました (exit code: $?)"
        echo "ループを停止します"
        break
    fi

    echo ""
done

echo ""
echo "=== Task Loop 終了 ==="
echo "処理タスク数: $COMPLETED"
ELAPSED=$(( ($(date +%s) - START_TIME) / 60 ))
echo "経過時間: ${ELAPSED}分"
