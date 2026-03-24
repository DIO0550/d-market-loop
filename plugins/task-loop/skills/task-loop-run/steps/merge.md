# マージ

0. Task.md の Processing エントリの Step を `merging` に更新
1. PRをマージする:
   ```bash
   gh pr merge {PR番号} --{mergeStrategy} --delete-branch
   ```
   ※ `deleteBranchAfterMerge` が `false` の場合は `--delete-branch` を省略
2. マージが失敗した場合（コンフリクト等）:
   - リベースを試みる:
     ```bash
     git fetch origin {baseBranch}
     git rebase origin/{baseBranch}
     ```
   - リベース成功 → プッシュしてマージを再試行
   - リベース失敗 → エラーリカバリーへ（`steps/error-recovery.md`）
3. ベースブランチに戻る:
   ```bash
   git checkout {baseBranch}
   git pull origin {baseBranch}
   ```
