# レビュー指摘修正

> ⚠️ **このステップは必ず全手順を最後まで実行すること。** 特に Step 5（再レビュー依頼）
> を省略すると外部ループが次のレビューを永久に待ち続け、タスクループ全体が停止する。
> Step 5 を実行せずにセッションを終了してはならない。

## 手順

### Step 1: 未解決スレッドから修正内容を特定
- review-check ステップで取得済みの未解決スレッド情報を使用する
- 各スレッドの `path`、`line`、`body` から修正箇所と内容を把握する

### Step 2: 修正を実装

### Step 3: 修正をコミット・プッシュ
- 修正したファイルのみを個別にステージングする（`git add -A` は使用禁止）
- コミットメッセージには具体的な修正内容を記述する
```bash
git add {修正したファイル1} {修正したファイル2} ...
git commit -m "fix: {具体的な修正内容の要約}"
git push
```

### Step 4: 修正したスレッドを解決済みにする
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

### Step 5: レビュアーに再レビューを依頼する ⚠️ 必須

**このステップを省略するとループ全体が停止する。**

Copilot は一度レビューを提出すると pending reviewers から外れるため、`gh pr edit --add-reviewer` で再度追加しないと次のレビューが走らない。`reviewer` は `task-loop-config.json` の `reviewer`（デフォルト `copilot-pull-request-reviewer`）。

```bash
gh pr edit {PR番号} --add-reviewer {reviewer}
```

成功を確認（exit code 0）してから Step 6 に進むこと。失敗した場合はリトライし、どうしても成功しない場合はエラーとして `steps/error-recovery.md` の汎用エラーフローへ。

### Step 6: 修正回数カウンタをインクリメント
`{tasksDir}/processing/.fix_count` を更新する:
- ファイルが無ければ `1` を書き込む
- あれば現在値 + 1 を書き込む
- 次回 `steps/review-check.md` Step 1 で `maxFixIterations` に到達すると「上限到達 → best-effort マージ」フローに入る

### Step 7: セッション終了（⚠️ 絶対に merge に進まない）

**このセッションはここで必ず終了する。** 以下のいずれもやってはいけない:

- ❌ `reviewThreads` を再取得して「未解決なし」を確認する
- ❌ `steps/review-check.md` に戻って分岐し直す
- ❌ `steps/merge.md` を実行する
- ❌ `gh pr merge` を呼び出す

Step 4 で修正済みスレッドを `resolveReviewThread` で resolved にしているため、
この時点で `reviewThreads` を再取得すると「未解決なし」に見える。ここでマージして
しまうと、**Copilot が新しいレビューを投稿する前に PR がマージされる**という
致命的な race condition になる（実際にこの不具合が観測されている）。

次の Copilot レビューは外部ループ (`run-loop.sh` の `poll_review`) が拾って、
**別の AI セッション**で `review-check.md` を起動する。本セッションの責務は
「修正して push して再レビュー依頼するところまで」で完結する。

## 終了前チェックリスト

セッションを終了する前に、以下が全て完了していることを自分で確認する:

- [ ] Step 3: 修正コミットを push した
- [ ] Step 4: 対応した全スレッドを `resolveReviewThread` で解決済みにした
- [ ] **Step 5: `gh pr edit --add-reviewer` を実行して exit 0 を確認した**
- [ ] Step 6: `.fix_count` を更新した

一つでも欠けていたら、その時点から再開すること。
