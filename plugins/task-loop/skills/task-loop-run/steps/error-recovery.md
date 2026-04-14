# エラーリカバリー

> 共通の前提: PR番号は `{tasksDir}/processing/.pr_number` から読む。`{tasksDir}` は `task-loop-config.json` の `tasksDir`（デフォルト `tasks`）。

## `fix_limit_exceeded` — 修正上限到達

`steps/review-check.md` の Step 1 で `.fix_count >= maxFixIterations` を検知したときに入る処理。後続タスクのブロックを避けるため、**可能な限り PR をマージする** ことを最優先とする。

1. **PR のマージを試みる**（`steps/merge.md` の手順）
   - mergeable なら `gh pr merge` で即マージする
   - マージコンフリクト等で失敗した場合のみリベース → 再マージを試みる
2. マージ結果にかかわらずタスクを `{tasksDir}/failed/` に移動し、frontmatter に以下を記録する:
   - `error: "fix_limit_exceeded"`
   - `merged: true | false`（マージ成否）
3. 状態更新のコミット（`steps/update-state.md` と同等の処理）を push する
4. **`stopOnError` の値に関わらず、このセッションは正常終了する**（次のタスクに進める必要があるため）

> `.pr_number` / `.fix_count` の削除は shell (`run-loop.sh` の `clean_processing_state`) がセッション終了後に行うため、AI 側では削除しない。

## 実装・コミット等の一般エラー

| エラー | 対処 |
|--------|------|
| 実装時にテストが通らない | 3回まで修正を試みる。それでも失敗 → `failed/` に移動 |
| git push が失敗 | 認証を確認、1回リトライ |
| PR作成が失敗 | 同名ブランチのPRが既にあるか確認。あれば再利用 |
| マージコンフリクト | リベースを試みる。失敗 → `failed/` に移動 |
| gh CLI未認証 | エラーメッセージを出して即座に終了 |

いずれのエラーでも:
- タスクファイルを `{tasksDir}/processing/` から `{tasksDir}/failed/` に移動する
- `stopOnError` が `true` → ループ終了（`steps/summary.md` へ）
- `stopOnError` が `false` → 次のタスクへ

> `.pr_number` / `.fix_count` の削除は shell 側が行う。AI 側では削除しない。
