# タスク初期化

1. タスクファイルを全文読み込む
2. frontmatterから `title`、`commitPrefix` を取得する（titleがない場合はファイル名のハイフン区切り部分を使用）
3. ベースブランチが最新であることを確認する:
   ```bash
   git checkout {baseBranch}
   git pull origin {baseBranch}
   ```
4. タスク用ブランチを作成する:
   ```bash
   git checkout -b {branchPrefix}{ファイル名から拡張子を除いたもの}
   ```
   例: `task/001-add-auth`
5. タスクファイルを `{tasksDir}/todo/` から `{tasksDir}/processing/` に移動する:
   ```bash
   mv {tasksDir}/todo/{タスクファイル} {tasksDir}/processing/{タスクファイル}
   ```
6. タスクファイルのfrontmatterに `assignedAt` を現在時刻で設定
