# タスク発見

1. `{tasksDir}/*.md` を取得する
2. ファイル名の昇順（辞書順）でソートする
3. 各ファイルのfrontmatterを読み、`status` を確認する
4. `status` が未設定または `pending` のタスクを「未処理」とする
5. `completed`、`failed`、`skipped` のタスクはスキップする
6. 最初の未処理タスクを選択する
7. 未処理タスクがなければループ終了（`steps/summary.md` の終了サマリーへ）
