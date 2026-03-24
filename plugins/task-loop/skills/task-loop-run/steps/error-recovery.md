# エラーリカバリー

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
- `stopOnError` が `true` → ループ終了（終了サマリーへ → `steps/summary.md`）
- `stopOnError` が `false` → 次のタスクへ
