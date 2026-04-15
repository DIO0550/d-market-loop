# レビュー指摘修正

> ⚠️ **このステップは必ず全手順を最後まで実行すること。** 特に Step 4（再レビュー依頼）
> を省略すると次回呼び出し時も Copilot が pending reviewers に入らないため新しい
> レビューが走らず、タスクが永久に進まなくなる。Step 4 を実行せずにセッションを
> 終了してはならない。

## 手順

### Step 1: 未解決スレッドを全て把握してグループ化

1. `steps/review-check.md` Step 2 で取得済みの `reviewThreads` から `isResolved: false`
   のスレッドを全て洗い出す。各スレッドについて以下を記録する:
   - `id`（後で `resolveReviewThread` に渡す）
   - `path` / `line`
   - `body`（指摘内容）
   - `author.login`
2. 指摘内容を **意味のあるまとまり** に分割する。グループ化の基準:
   - 同じファイル / 同じ関数に対する指摘はまとめる
   - 同じ種類の問題（命名・型・エラーハンドリング・テスト不足・import 整理等）はまとめる
   - 修正内容が相互に影響する指摘は 1 グループにする
   - それ以外は独立した単位で分ける
3. 各グループは「独立してテスト可能・1 コミットにできる単位」になるようにする。
   1 件しか指摘が無い場合は 1 グループ 1 件でよい。

分割の例:
- グループ A: `src/foo.ts` の型指摘 3 件 → 1 コミット
- グループ B: `src/bar.ts` のエラーハンドリング指摘 2 件 → 1 コミット
- グループ C: テスト追加の指摘 1 件 → 1 コミット

### Step 2: 各グループを順に処理する

グループごとに以下 2-A 〜 2-D を **必ずこの順で** 実行する。1 グループが完了してから
次のグループに進む。

#### Step 2-A: 修正を実装

対象ファイルを編集する。このグループに含まれる指摘だけを対象にし、関係の無い
変更は混ぜない。

#### Step 2-B: テストが通ることを確認

プロジェクトのテストコマンドを実行して通過を確認する。テストコマンドは以下の優先順で決定:

1. タスクファイルの `Test Command` フィールド
2. `task-loop-config.json` の `allowedCommands` / Task.md の `Tech Stack` から読み取れる
   プロジェクト標準コマンド（例: `pnpm test`, `vitest`, `pnpm run typecheck`）
3. 型チェックだけでも通すべきケースは `tsc --noEmit`

テストが失敗したら:
- 原因を調べて修正し、再実行する
- 3 回修正しても通らない場合は `steps/error-recovery.md` の汎用エラーフローへ

> テストコマンドが存在しない/判別できない場合は、このグループで触ったファイルに
> 対する型チェックだけでも実行すること。無言でスキップしてはならない。

#### Step 2-C: コミット・プッシュ

このグループで修正したファイルのみを個別にステージングする（`git add -A` は使用禁止）。
コミットメッセージには具体的な修正内容を記述する。

```bash
git add {修正したファイル1} {修正したファイル2} ...
git commit -m "fix: {グループの修正内容の要約}"
git push
```

#### Step 2-D: 対象のレビュー指摘を解決済みにする

このグループで対応したスレッドの `id` を全て `resolveReviewThread` する。
**他のグループのスレッドはまだ触らない**（そのグループの処理時に解決する）。

```bash
gh api graphql -f query='
  mutation($id: ID!) {
    resolveReviewThread(input: {threadId: $id}) {
      thread { isResolved }
    }
  }
' -f id='{このグループのスレッドID}'
```

各スレッドに対して 1 回ずつ実行。

---

全グループの Step 2-A 〜 2-D が完了したら Step 3 へ進む。

### Step 3: 全グループ処理完了の確認

- 未解決だった全スレッドが `resolveReviewThread` 済みになっていること
- 全グループのコミットが push 済みであること
- 全グループのテストが通過していること

1 つでも欠けていたらその時点から再開する。

### Step 4: レビュアーに再レビューを依頼する ⚠️ 必須

**このステップを省略するとタスクループ全体が停止する。**

Copilot は一度レビューを提出すると pending reviewers から外れるため、`gh pr edit --add-reviewer` で再度追加しないと次のレビューが走らない。`reviewer` は `task-loop-config.json` の `reviewer`（デフォルト `copilot-pull-request-reviewer`）。

なお、この直後の `reviewRequests` は `reviewer` を含む状態になる。これは次回の
`steps/review-check.md` Step 3-A が「進行中」と判定するための唯一の根拠になるので、
このコマンドの成功確認は必須。

```bash
gh pr edit {PR番号} --add-reviewer {reviewer}
```

成功を確認（exit code 0）してから Step 5 に進むこと。失敗した場合はリトライし、どうしても成功しない場合はエラーとして `steps/error-recovery.md` の汎用エラーフローへ。

### Step 5: 修正回数カウンタをインクリメント

`{tasksDir}/processing/.fix_count` を更新する:
- ファイルが無ければ `1` を書き込む
- あれば現在値 + 1 を書き込む
- 次回 `steps/review-check.md` Step 1 で `maxFixIterations` に到達すると「上限到達 → best-effort マージ」フローに入る

**重要**: `.fix_count` は「fix セッション」に対する 1 回のカウントであり、グループ数
では **ない**。グループをいくつ処理しても `.fix_count` は +1 のみ。

### Step 6: セッション終了（⚠️ 絶対に merge に進まない）

**このセッションはここで必ず終了する。** 以下のいずれもやってはいけない:

- ❌ `reviewThreads` を再取得して「未解決なし」を確認する
- ❌ `steps/review-check.md` に戻って分岐し直す
- ❌ `steps/merge.md` を実行する
- ❌ `gh pr merge` を呼び出す

Step 2-D で修正済みスレッドを `resolveReviewThread` で resolved にしているため、
この時点で `reviewThreads` を再取得すると「未解決なし」に見える。ここでマージして
しまうと、**Copilot が新しいレビューを投稿する前に PR がマージされる**という
致命的な race condition になる（実際にこの不具合が観測されている）。

本セッションの責務は「グループ分け → 各グループの修正・テスト・コミット・スレッド解決
→ 再レビュー依頼 → `.fix_count` インクリメント」までで完結する。push により
HEAD が変わり、Step 4 で Copilot が pending reviewers に入っているため、次回呼び出し
時の `steps/review-check.md` Step 3-A が「進行中」と判定して待つ。Copilot の新
レビュー到着後のさらに次の呼び出しで改めて fix / merge を判断する。

なお、仮にこのセッション内で `gh pr merge` を呼んでも `pre-tool-use-hook` が
`reviewRequests` に reviewer が含まれている（進行中）と判定して deny する。

## 終了前チェックリスト

セッションを終了する前に、以下が全て完了していることを自分で確認する:

- [ ] Step 1: 未解決スレッドを全て洗い出し、意味のあるまとまりに分割した
- [ ] Step 2: **全グループ** について 2-A 修正 → 2-B テスト通過 → 2-C コミット・push → 2-D 対象スレッド解決 を完了した
- [ ] Step 3: 全ての未解決スレッドが resolved になり、全コミットが push 済みである
- [ ] **Step 4: `gh pr edit --add-reviewer` を実行して exit 0 を確認した**
- [ ] Step 5: `.fix_count` を更新した

一つでも欠けていたら、その時点から再開すること。
