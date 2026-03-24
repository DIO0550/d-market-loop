# レビュー指摘修正

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
