# Task Loop 指示書

/task-loop-run を実行して、タスクを **1つだけ** 処理してください。

## ルール

- 1回の実行で処理するタスクは1つだけ。完了または失敗したら終了する。
- 処理開始前に baseBranch を最新にすること（`git checkout {baseBranch} && git pull origin {baseBranch}`）。
- PRマージ後も baseBranch に戻り最新を pull してから終了すること。次回実行時にクリーンな状態で始められるようにする。
