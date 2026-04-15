# レビュー指摘修正

> ⚠️ **このステップは必ず全手順を最後まで実行すること。** 特に Step 5（再レビュー依頼）
> を省略すると次回呼び出し時も Copilot が pending reviewers に入らないため新しい
> レビューが走らず、タスクが永久に進まなくなる。Step 5 を実行せずにセッションを
> 終了してはならない。

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

**このステップを省略するとタスクループ全体が停止する。**

Copilot は一度レビューを提出すると pending reviewers から外れるため、`gh pr edit --add-reviewer` で再度追加しないと次のレビューが走らない。`reviewer` は `task-loop-config.json` の `reviewer`（デフォルト `copilot-pull-request-reviewer`）。

なお、この直後の `reviewRequests` は `reviewer` を含む状態になる。これは次回の
`steps/review-check.md` Step 3-A が「進行中」と判定するための唯一の根拠になるので、
このコマンドの成功確認は必須。

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

本セッションの責務は「修正 → push → スレッド解決 → 再レビュー依頼 → `.fix_count`
インクリメント」までで完結する。push により HEAD が変わり、Step 5 で Copilot が
pending reviewers に入っているため、次回呼び出し時の `steps/review-check.md`
Step 3-A が「進行中」と判定して待つ。Copilot の新レビュー到着後のさらに次の
呼び出しで改めて fix / merge を判断する。

なお、仮にこのセッション内で `gh pr merge` を呼んでも `pre-tool-use-hook` が
`reviewRequests` に reviewer が含まれている（進行中）と判定して deny する。

## 終了前チェックリスト

セッションを終了する前に、以下が全て完了していることを自分で確認する:

- [ ] Step 3: 修正コミットを push した
- [ ] Step 4: 対応した全スレッドを `resolveReviewThread` で解決済みにした
- [ ] **Step 5: `gh pr edit --add-reviewer` を実行して exit 0 を確認した**
- [ ] Step 6: `.fix_count` を更新した

一つでも欠けていたら、その時点から再開すること。
