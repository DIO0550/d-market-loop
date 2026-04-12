# レビュー指摘修正

1. 未解決のレビュースレッドから修正すべき指摘を特定する
   - review-check ステップで取得済みの未解決スレッド情報を使用する
   - 各スレッドの `path`、`line`、`body` から修正箇所と内容を把握する
2. 指摘に対して修正を実装する
3. 修正をコミットする:
   - 修正したファイルのみを個別にステージングする（`git add -A` は使用禁止）
   - コミットメッセージには具体的な修正内容を記述する
   ```bash
   git add {修正したファイル1} {修正したファイル2} ...
   git commit -m "fix: {具体的な修正内容の要約}"
   git push
   ```
4. 修正したスレッドを解決済みにする:
   ```bash
   gh api graphql -f query='
     mutation($id: ID!) {
       resolveReviewThread(input: {threadId: $id}) {
         thread { isResolved }
       }
     }
   ' -f id='{スレッドID}'
   ```
   各修正済みスレッドに対してこのコマンドを実行する。
5. レビュアーに再レビューを依頼する:
   ```bash
   gh pr edit {PR番号} --add-reviewer {reviewer}
   ```
6. 修正回数のカウントと上限チェックは外部ループ（`run-loop.sh`）が管理する
7. 修正コミット・プッシュ後、**レビュー待ちには入らず AIセッションを終了する**
   - 外部ループが再度レビューポーリングを行い、必要に応じて再度 fix モードで呼び出す
