# Task Loop 指示書

/task-loop-run を実行して、タスクを **1つだけ** 処理してください。

## タスクフォルダのルール

タスクディレクトリ（デフォルト: `tasks/`）には以下のサブフォルダがある:

- `todo/` — 未処理のタスクファイル
- `processing/` — 処理中のタスクファイル
- `done/` — 完了したタスクファイル
- `failed/` — 失敗したタスクファイル

### タスクの選択

1. `processing/` にファイルがあれば、それを読み込んで続きから処理する（中断復帰）。
2. `processing/` が空なら、`todo/` から番号順で最初の1つを `processing/` に移動し、タスク用ブランチを作成して処理を開始する（`git checkout -b {branchPrefix}{タスク名}`）。
3. `todo/` も `processing/` も空なら、処理するタスクがないので終了する。

### タスク完了時

- 成功 → `processing/` から `done/` にファイルを移動する。
- 失敗 → `processing/` から `failed/` にファイルを移動する。

## その他のルール

- 1回の実行で処理するタスクは1つだけ。完了または失敗したら終了する。
- 処理開始前に baseBranch を最新にすること（`git checkout {baseBranch} && git pull origin {baseBranch}`）。
- PRマージ後も baseBranch に戻り最新を pull してから終了すること。次回実行時にクリーンな状態で始められるようにする。
