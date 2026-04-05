# 状態更新

1. タスクファイルを `{tasksDir}/processing/` から `{tasksDir}/done/` に移動する:
   ```bash
   mv {tasksDir}/processing/{タスクファイル} {tasksDir}/done/{タスクファイル}
   ```
2. タスクファイルのfrontmatterを更新:
   - `completedAt` に現在時刻を設定
3. 状態更新をコミットする:
   ```bash
   git add {タスクファイル（移動前後のパス）}
   git commit -m "chore: mark {ファイル名} as completed"
   git push origin {baseBranch}
   ```
