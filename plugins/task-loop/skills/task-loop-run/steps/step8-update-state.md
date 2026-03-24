# Step 8: 状態更新

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
