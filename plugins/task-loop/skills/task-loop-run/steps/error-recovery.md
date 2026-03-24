# エラーリカバリー

| エラー | 対処 |
|--------|------|
| 実装時にテストが通らない | 3回まで修正を試みる。それでも失敗 → `failed/` に移動 |
| git push が失敗 | 認証を確認、1回リトライ |
| PR作成が失敗 | 同名ブランチのPRが既にあるか確認。あれば再利用 |
| レビュータイムアウト | `autoMergeWithoutReview` の設定に従う |
| 修正上限到達 | `needs_manual_review` として記録 |
| マージコンフリクト | リベースを試みる。失敗 → `failed/` に移動 |
| gh CLI未認証 | エラーメッセージを出して即座に終了 |

いずれのエラーでも:
- タスクファイルを `{tasksDir}/processing/` から `{tasksDir}/failed/` に移動する
- `task-loop-state.json` にエラー状態を記録する
- `stopOnError` が `true` → ループ終了（終了サマリーへ → `steps/summary.md`）
- `stopOnError` が `false` → 次のタスクへ
