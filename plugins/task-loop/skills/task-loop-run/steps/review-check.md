# review-check モード: Steps 5〜6

## Step 5: レビュー待ち（外部ループが担当）

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
   - 指摘なし → AIがそのままマージ（`steps/merge.md` を参照）
   - 指摘あり → AIが修正（Step 6）して終了、外部ループが再ポーリング
3. `reviewMaxWaitMinutes` を超えた場合:
   - `autoMergeWithoutReview` が `true` → merge モード実行
   - `autoMergeWithoutReview` が `false` → ユーザーに通知して次のタスクへ

## Step 6: レビュー指摘修正

0. Task.md の Processing エントリの Step を `fixing` に更新
1. PRのレビューコメントを取得する:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{PR番号}/comments
   gh pr view {PR番号} --json reviews
   ```
2. 各コメントの指摘内容を解析する
3. 指摘に対して修正を実装する
4. 修正をコミットする:
   - 修正したファイルのみを個別にステージングする（`git add -A` は使用禁止）
   - コミットメッセージには具体的な修正内容を記述する
   ```bash
   git add {修正したファイル1} {修正したファイル2} ...
   git commit -m "fix: {具体的な修正内容の要約}"
   git push
   ```
5. 修正回数のカウントと上限チェックは外部ループ（`run-loop.sh`）が管理する
6. 修正コミット・プッシュ後、**レビュー待ちには入らず AIセッションを終了する**
   - Task.md の Processing エントリの Step を `reviewing` に更新してから終了
   - 外部ループが再度レビューポーリングを行い、必要に応じて再度 fix モードで呼び出す
