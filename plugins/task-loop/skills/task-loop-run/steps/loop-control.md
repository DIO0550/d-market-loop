# ループ制御・エラーリカバリー

## Step 9: ループ条件チェック

以下の条件を順にチェックし、いずれかに該当すればループを終了する:

1. **残タスクなし**: 未処理のタスクファイルがない → 終了
2. **maxTasks到達**: 処理したタスク数 >= `maxTasks`（maxTasks > 0 の場合） → 終了
3. **時間制限超過**: ループ開始からの経過時間 > `timeLimitMinutes`（timeLimitMinutes > 0 の場合） → 終了

条件に該当しなければ、タスク発見に戻り次のタスクを処理する。

## エラーリカバリー

| エラー | 対処 |
|--------|------|
| 実装時にテストが通らない | 3回まで修正を試みる。それでも失敗 → `status: failed` に更新 |
| git push が失敗 | 認証を確認、1回リトライ |
| PR作成が失敗 | 同名ブランチのPRが既にあるか確認。あれば再利用 |
| レビュータイムアウト | `autoMergeWithoutReview` の設定に従う |
| 修正上限到達 | `needs_manual_review` として記録 |
| マージコンフリクト | リベースを試みる。失敗 → `status: failed` |
| gh CLI未認証 | エラーメッセージを出して即座に終了 |

いずれのエラーでも:
- `task-loop-state.json` にエラー状態を記録する
- Task.md を更新: タスクエントリを **Processing** → **Failed** に移動
  - チェックボックスを除去（`- **ID**` 形式にする）
  - `StartedAt`、`Branch`、`Step` フィールドを削除
  - `FailedAt`（現在時刻）、`Reason`（失敗理由）を追加
  - PR が作成済みなら `PR`（PR URL）を追加
  - frontmatter の `updatedAt` を更新
- `stopOnError` が `true` → ループ終了（終了サマリーへ）
- `stopOnError` が `false` → 次のタスクへ

## 終了サマリー

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
