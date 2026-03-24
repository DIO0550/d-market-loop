# Step 1: タスク初期化

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
5. タスクファイルのfrontmatterを `status: in_progress` に更新、`assignedAt` に現在時刻を設定
6. `task-loop-state.json` にタスクエントリを追加（status: "in_progress"、startedAt）
7. Task.md を更新: タスクエントリを **Todo** → **Processing** に移動
   - `Priority` フィールドを削除
   - `StartedAt`（現在時刻）、`Branch`（ブランチ名）、`Step: implementing` を追加
   - frontmatter の `updatedAt` を更新
