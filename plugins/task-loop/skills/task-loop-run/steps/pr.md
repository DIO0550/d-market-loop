# PR作成

1. ブランチをプッシュする:
   ```bash
   git push -u origin {ブランチ名}
   ```
2. PR本文を生成する:
   - タスクの Description を要約
   - 変更内容の箇条書き
   - テスト方法（Test Command があれば記載）
   - フッター（設定の `prBodyFooter`）
3. PRを作成する:
   ```bash
   gh pr create --title "{commitPrefix}: {title}" --body "{PR本文}" --base {baseBranch}
   ```
4. レビュアーを設定する:
   ```bash
   gh pr edit {PR番号} --add-reviewer {reviewer}
   ```
5. PR番号とURLを記録する
6. タスクファイルのfrontmatterに `prUrl` と `prNumber` を設定
7. PR番号を `{tasksDir}/processing/.pr_number` に書き出す（次回呼び出し時の `steps/review-check.md` が参照する）
