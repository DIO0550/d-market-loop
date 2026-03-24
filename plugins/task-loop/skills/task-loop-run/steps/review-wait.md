# レビュー待ち（外部ループが担当）

> **注意**: このステップは `run-loop.sh`（外部シェルループ）が担当する。
> AI セッション内では `sleep` によるポーリングを**行わない**。

0. Task.md の Processing エントリの Step を `reviewing` に更新
1. **AI セッションはここで終了する** — PR作成後、レビュー待ちには入らない

外部ループ（`run-loop.sh`）が以下を実行する:

1. `reviewRequests` と `reviews` をポーリングし、レビュー完了を検知する:
   ```bash
   # レビュアーがまだレビュー依頼中（処理中）か確認
   gh pr view {PR番号} --json reviewRequests --jq '.reviewRequests[].login'
   # レビュー済みの状態を確認
   gh pr view {PR番号} --json reviews --jq '.reviews[] | {user: .author.login, state: .state}'
   ```
   - `reviewRequests` にレビュアーがいる → まだレビュー中、待機継続
   - `reviewRequests` から消え、`reviews` に `COMMENTED` 等が入った → レビュー完了
2. レビュー完了 → 新しいAIセッションで **review-check** モード実行
   - AIがコメント内容を分析し、修正指摘の有無を判断
   - 指摘なし → AIがそのままマージ（`steps/merge.md`）
   - 指摘あり → AIが修正（`steps/fix.md`）して終了、外部ループが再ポーリング
3. `reviewMaxWaitMinutes` を超えた場合:
   - `autoMergeWithoutReview` が `true` → merge モード実行
   - `autoMergeWithoutReview` が `false` → ユーザーに通知して次のタスクへ
