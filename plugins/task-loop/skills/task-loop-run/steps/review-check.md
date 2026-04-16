# レビュー結果の判定（fix / merge / 進行中 / CI 失敗 / 上限到達時の best-effort マージ）

`processing/.pr_number` が存在する状態で呼び出された場合、本ステップで分岐を決定する。

> **前提**: レビュー進行中の判定は本ステップで行う。Copilot が再レビュー依頼中や
> 追加コメント投稿中の PR に対して `reviewThreads.isResolved` を信じて fix / merge
> してはならない。進行中の判定条件と GraphQL クエリは
> `references/copilot-in-progress-check.md` を参照。

## 手順

### Step 0: 状態を読み込む

- PR番号: `{tasksDir}/processing/.pr_number` から読み込む（`{tasksDir}` は `task-loop-config.json` の `tasksDir`、デフォルト `tasks`）
- 修正回数: `{tasksDir}/processing/.fix_count` から読み込む（ファイル無しなら 0）
- 上限: `task-loop-config.json` の `maxFixIterations`（デフォルト 3）
- CI自動修正: `task-loop-config.json` の `ciAutoFix`（デフォルト `true`）
- レビュアー: `task-loop-config.json` の `reviewer`（デフォルト `copilot-pull-request-reviewer`）
- 進行中窓: `task-loop-config.json` の `reviewInProgressWindowSeconds`（デフォルト 60）
- owner / repo: `git remote get-url origin` から取得

### Step 1: 上限判定（fix_count >= maxFixIterations）

`maxFixIterations` が **`-1` の場合は無制限**（解決するまで fix し続ける）とみなし、本ステップはスキップして Step 2 へ進む。

それ以外で `.fix_count` が `maxFixIterations` 以上なら、これ以上 fix しても収束しないと判断し、
**後続タスクのブロックを避けるため可能な限りマージする**:

- `maxFixIterations = 0` → `.fix_count` (0) >= 0 で即ヒット → fix せず即フォールバックへ
- `maxFixIterations = 3` → 3回 fix した後（`.fix_count = 3`）でヒット

→ `steps/error-recovery.md` の `fix_limit_exceeded` セクションへ進む（best-effort merge + failed 記録 + 正常終了）

上限未満なら Step 2 へ。

### Step 2: PR の状態をワンショット取得

`references/copilot-in-progress-check.md` の GraphQL クエリを 1 回だけ実行し、以下を
同時に取得する:

- `reviewRequests.nodes[].requestedReviewer` — 誰が pending reviewers か
- `reviews.nodes[]` — 各 review の `author.login` と `state`
- `reviewThreads.nodes[]` — 各スレッドの `isResolved` と `comments[].createdAt` / `body` / `path` / `line` / `author.login`

クエリ例（`references/copilot-in-progress-check.md` のクエリを使用。レビュー状態・スレッド・CI 状態を 1 ショットで取得する）:

```bash
gh api graphql \
  -f owner='{owner}' -f repo='{repo}' -F number={PR番号} \
  -f reviewer='{reviewer}' -F window={reviewInProgressWindowSeconds} \
  -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewRequests(first: 100) {
            nodes {
              requestedReviewer {
                __typename
                ... on User { login }
                ... on Bot { login }
              }
            }
          }
          reviews(first: 100) {
            nodes { author { login } state }
          }
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              comments(first: 10) {
                nodes { body path line author { login } createdAt }
              }
            }
          }
          commits(last: 1) {
            nodes {
              commit {
                statusCheckRollup {
                  state
                  contexts(first: 100) {
                    nodes {
                      __typename
                      ... on CheckRun { name status conclusion detailsUrl }
                      ... on StatusContext { context state targetUrl }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  '
```

### Step 3-A: レビュー進行中判定（最優先）

`references/copilot-in-progress-check.md` の判定ロジックに従って進行中判定する:

- `reviewRequests` に `reviewer` が含まれている → `REQUESTED`
- `reviewer` による `state=PENDING` の review がある → `PENDING`
- `reviewThreads.nodes[].comments[].createdAt` の最大値が `now - reviewInProgressWindowSeconds` 秒以内 → `RECENT_COMMENT`

上記いずれかにヒットしたら **何もせずセッションを終了する**:

- `processing/` のタスクファイルはそのまま残す
- `.fix_count` は触らない
- `.pr_number` も削除しない
- `steps/fix.md` にも `steps/merge.md` にも進まない

理由: Copilot のレビューが完全には届いていない状態で `isResolved: false` の有無を
見ても、新しい未解決コメントを見逃して merge に進んでしまう可能性があるため。
次回の呼び出しで再度 Step 2 から状態を観測する。

### Step 3-B: CI ステータス判定

Step 3-A で進行中でないと判定された場合のみ本ステップに進む。

Step 2 で取得した `commits(last:1).nodes[0].commit.statusCheckRollup` を確認する。

- **`statusCheckRollup` が `null`（CI 未設定）** → **Step 3-B をスキップ**して Step 3-C へ進む。CI に関するロジックには一切入らない
- **`statusCheckRollup.state` が `SUCCESS`** → CI 通過。Step 3-C へ
- **`statusCheckRollup.state` が `PENDING` / `EXPECTED`** → CI 実行中。**何もせず即終了**（Step 3-A の進行中と同様。`processing/` を残したまま待機）
- **`statusCheckRollup.state` が `FAILURE` / `ERROR`** → CI 失敗。以下で分岐:
  - `ciAutoFix` が `false` → `steps/error-recovery.md` の `ci_auto_fix_disabled` セクションへ → **終了**
  - `ciAutoFix` が `true`（デフォルト） → `steps/ci-fix.md` の全手順を実行 → **終了**

> CI 失敗の修正はレビュースレッドの修正より優先する。ビルドが通らないコードの
> レビュー指摘を修正しても、CI 通過後のレビューで別の指摘が出る可能性があるため。

### Step 3-C: `isResolved: false` のスレッドの有無で分岐

Step 3-A で進行中でなく、Step 3-B で CI が通過（または CI 未設定）と判定された場合のみ本ステップに進む。

**分岐は一方通行。fix ルートに入ったら merge ルートには絶対に戻らない。**

- **未解決スレッドなし** → `steps/merge.md` → `steps/update-state.md` → **終了**
- **未解決スレッドあり** → `steps/fix.md` の**全手順**を実行 → **終了**
  - 修正 → コミット・プッシュ → スレッド解決 → 再レビュー依頼 → `.fix_count` インクリメント まで**必ず全て実施**する
  - 再レビュー依頼（`gh pr edit --add-reviewer`）を省略すると次回呼び出し時も `reviewRequests` が空のまま新しいレビューが走らない
  - ⚠️ **fix.md 完了後に `reviewThreads` を再取得して merge に進んではならない。** 各グループの Step 2-D で自分で resolved にしているため「未解決なし」に見えるが、push により HEAD が変わっており、Copilot の新しいレビューはまだ届いていない。次の review-check は次回呼び出し時に起動する
