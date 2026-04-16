# CI 失敗修正

> このステップは `steps/review-check.md` の Step 3-B で CI 失敗を検知し、
> `ciAutoFix` が `true` の場合にだけ呼ばれる。
>
> ⚠️ **このステップは必ず全手順を最後まで実行すること。** 特に Step 5（再レビュー依頼）
> を省略すると次回呼び出し時に Copilot が新しいレビューを走らせず、タスクが進まなくなる。

## 手順

### Step 1: 失敗した CI チェックを特定

`gh pr checks` で失敗チェックの一覧を取得する:

```bash
gh pr checks {PR番号} --json name,state,conclusion
```

`conclusion` が `failure` または `startup_failure` のチェックが修正対象。
各チェックの `name` からどの種類のチェックか（build / test / lint / typecheck 等）を推測する。

### Step 2: ローカルで同等のコマンドを再現し修正する

失敗したチェックの種類に対応するローカルコマンドを実行して、エラー内容を確認する:

| CI チェックの種類 | ローカルで実行するコマンド例 |
|-----------------|--------------------------|
| build | `pnpm run build` / `tsc -p tsconfig.json` |
| test | `pnpm test` / `vitest` / `jest` |
| lint | `eslint .` / `prettier --check .` |
| typecheck | `tsc --noEmit` |

実行するコマンドの優先順:
1. タスクファイルの `Test Command` フィールド
2. `task-loop-config.json` の `allowedCommands` / Task.md の `Tech Stack` から判断
3. CI チェック名からの推測

エラー出力を読み、原因を特定してコードを修正する。

### Step 3: ローカルテスト通過を確認

Step 2 で失敗していたコマンドを再実行して通過を確認する。

テストが失敗したら:
- 原因を調べて修正し、再実行する
- 3 回修正しても通らない場合は `steps/error-recovery.md` の汎用エラーフローへ

> テストコマンドが存在しない/判別できない場合は、修正したファイルに対する
> 型チェックだけでも実行すること。無言でスキップしてはならない。

### Step 4: コミット・プッシュ

`steps/commit.md` の規則に従って変更をコミットする。`commitPrefix` は `fix` を使う。

コミット作成後に push する:

```bash
git push
```

### Step 5: レビュアーに再レビュー依頼する ⚠️ 必須

**このステップを省略するとタスクループ全体が停止する。**

push で HEAD が変わるため、`steps/fix.md` Step 4 と同様に再レビュー依頼が必要。
`reviewer` は `task-loop-config.json` の `reviewer`（デフォルト `copilot-pull-request-reviewer`）。

```bash
gh pr edit {PR番号} --add-reviewer {reviewer}
```

成功を確認（exit code 0）してから Step 6 に進むこと。失敗した場合はリトライし、
どうしても成功しない場合はエラーとして `steps/error-recovery.md` の汎用エラーフローへ。

### Step 6: セッション終了（⚠️ 絶対に merge に進まない）

**このセッションはここで必ず終了する。** 以下のいずれもやってはいけない:

- ❌ `statusCheckRollup` を再取得して CI 通過を確認する
- ❌ `reviewThreads` を再取得して「未解決なし」を確認する
- ❌ `steps/review-check.md` に戻って分岐し直す
- ❌ `steps/merge.md` を実行する
- ❌ `gh pr merge` を呼び出す

push により HEAD が変わっており、CI が再実行される。CI の結果と Copilot の新しい
レビューが届くのは次回呼び出し時。本セッションの責務は「CI 失敗の特定 → ローカル
再現 → 修正 → テスト → コミット・push → 再レビュー依頼」までで完結する。

なお、仮にこのセッション内で `gh pr merge` を呼んでも `pre-tool-use-hook` が
CI 未通過または reviewer 進行中と判定して deny する。

## 終了前チェックリスト

セッションを終了する前に、以下が全て完了していることを自分で確認する:

- [ ] Step 1: 失敗した CI チェックを特定した
- [ ] Step 2: ローカルで再現し、コードを修正した
- [ ] Step 3: ローカルテストが通過した
- [ ] Step 4: コミットして push した
- [ ] **Step 5: `gh pr edit --add-reviewer` を実行して exit 0 を確認した**

一つでも欠けていたら、その時点から再開すること。
