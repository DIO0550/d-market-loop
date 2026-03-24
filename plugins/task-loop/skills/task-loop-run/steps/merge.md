# マージ・状態更新: Steps 7〜8

## Step 7: マージ

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
   - リベース失敗 → エラーリカバリーへ
3. ベースブランチに戻る:
   ```bash
   git checkout {baseBranch}
   git pull origin {baseBranch}
   ```

## Step 8: 状態更新

1. タスクファイルのfrontmatterを更新:
   - `status: completed`
   - `completedAt` に現在時刻を設定
2. `task-loop-state.json` を更新:
   - タスクの `status` を `"completed"` に
   - `completedAt` を設定
   - `tasksCompleted` カウンタを+1
   - `lastUpdatedAt` を更新
3. Task.md を更新: タスクエントリを **Processing** → **Done** に移動
   - チェックボックスを `- [x]` に変更
   - `StartedAt`、`Branch`、`Step` フィールドを削除
   - `CompletedAt`（現在時刻）、`PR`（PR URL）を追加
   - frontmatter の `updatedAt` を更新
4. 状態更新をコミットする:
   ```bash
   git add {タスクファイル} {stateFile} {planFile}
   git commit -m "chore: mark {ファイル名} as completed"
   git push origin {baseBranch}
   ```
