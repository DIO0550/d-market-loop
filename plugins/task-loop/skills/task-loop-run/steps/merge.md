# マージ

> 本ステップは `steps/review-check.md` の Step 3-B で「進行中でない & 未解決なし」と
> 判定された場合にだけ呼ばれる。仮にそれ以外の状況で `gh pr merge` を呼んでも、
> `pre-tool-use-hook` が `reviewRequests` / PENDING / 直近コメント窓を再検証して
> 進行中なら deny する（`references/copilot-in-progress-check.md` 参照）。

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
