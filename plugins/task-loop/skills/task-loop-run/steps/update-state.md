# 状態更新

1. タスクファイルを `{tasksDir}/processing/` から `{tasksDir}/done/` に移動する:
   ```bash
   mv {tasksDir}/processing/{タスクファイル} {tasksDir}/done/{タスクファイル}
   ```
2. タスクファイルのfrontmatterを更新:
   - `completedAt` に現在時刻を設定
3. `task-loop-state.json` を更新:
   - タスクの `status` を `"completed"` に
   - `completedAt` を設定
   - `tasksCompleted` カウンタを+1
   - `lastUpdatedAt` を更新
4. 状態更新をコミットする:
   ```bash
   git add {タスクファイル（移動前後のパス）} {stateFile}
   git commit -m "chore: mark {ファイル名} as completed"
   git push origin {baseBranch}
   ```
