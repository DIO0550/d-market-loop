# レビュー結果の判定（fix / merge / 上限到達時の best-effort マージ）

`processing/.pr_number` が存在する状態で呼び出された場合、本ステップで分岐を決定する。

> **前提**: 「レビューがまだ進行中か」の判定は外部ループ（`run-loop.sh` の
> `wait_for_review_stable`）が完了させている。本ステップでは進行中チェックは
> **行わない**。ファイル状態と未解決スレッドだけを見て判断する。

## 手順

### Step 0: 状態を読み込む

- PR番号: `{tasksDir}/processing/.pr_number` から読み込む（`{tasksDir}` は `task-loop-config.json` の `tasksDir`、デフォルト `tasks`）
- 修正回数: `{tasksDir}/processing/.fix_count` から読み込む（ファイル無しなら 0）
- 上限: `task-loop-config.json` の `maxFixIterations`（デフォルト 3）

### Step 1: 上限判定（fix_count >= maxFixIterations）

`maxFixIterations` が **`-1` の場合は無制限**（解決するまで fix し続ける）とみなし、本ステップはスキップして Step 2 へ進む。

それ以外で `.fix_count` が `maxFixIterations` 以上なら、これ以上 fix しても収束しないと判断し、
**後続タスクのブロックを避けるため可能な限りマージする**:

- `maxFixIterations = 0` → `.fix_count` (0) >= 0 で即ヒット → fix せず即フォールバックへ
- `maxFixIterations = 3` → 3回 fix した後（`.fix_count = 3`）でヒット

→ `steps/error-recovery.md` の `fix_limit_exceeded` セクションへ進む（best-effort merge + failed 記録 + 正常終了）

上限未満なら Step 2 へ。

### Step 2: 未解決のレビュースレッドを取得

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 10) {
              nodes { body path line author { login } }
            }
          }
        }
      }
    }
  }
' -f owner='{owner}' -f repo='{repo}' -F number={PR番号}
```
※ `{owner}` と `{repo}` は `git remote get-url origin` から取得

### Step 3: `isResolved: false` のスレッドの有無で分岐

- **未解決スレッドなし** → `steps/merge.md` → `steps/update-state.md`
- **未解決スレッドあり** → `steps/fix.md` の**全手順**を実行
  - 修正 → コミット・プッシュ → スレッド解決 → 再レビュー依頼 → `.fix_count` インクリメント まで**必ず全て実施**する
  - 再レビュー依頼（`gh pr edit --add-reviewer`）を省略すると外部ループが次のレビューを永久に待ち続ける
