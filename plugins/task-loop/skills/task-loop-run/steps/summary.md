# 終了サマリー

ループ終了時に以下のサマリーを出力する:

```
Task Loop 完了

処理結果:
  完了: {tasksCompleted} タスク
  失敗: {tasksFailed} タスク
  スキップ: {tasksSkipped} タスク
  残り: {remaining} タスク

PR一覧:
  - #{prNumber} {title} ({prUrl}) [完了]
  - #{prNumber} {title} ({prUrl}) [失敗]

{手動対応が必要なタスクがあれば}
手動対応が必要:
  - {ファイル名}: {理由}

終了理由: {全タスク完了 / maxTasks到達 / 時間制限超過 / エラー停止}
```
