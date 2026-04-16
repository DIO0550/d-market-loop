# Copilot レビュー進行中チェック

`gh pr edit --add-reviewer` で再レビュー依頼した直後や、Copilot がインラインコメントを順次投稿している最中は「レビュー進行中」とみなし、`reviewThreads` の `isResolved` を信じて行動してはならない。

本チェックはワンショット GraphQL で行う。`sleep` による能動的ポーリングはしない。

## 進行中と判定する条件

以下の **いずれか一つ** にヒットしたら「進行中」とみなす:

1. **`reviewRequests` に `reviewer` が入っている**
   再レビュー依頼後、まだレビューが返ってきていない状態
2. **`reviewer` による `state=PENDING` の review がある**
   ドラフトレビュー状態（主に human reviewer 用）
3. **`reviewThreads.comments.createdAt` の最大値が直近 `reviewInProgressWindowSeconds` 秒以内**
   Copilot が追加コメントを順次投稿している途中

`reviewer` / `reviewInProgressWindowSeconds` は `task-loop-config.json` から読む。デフォルトはそれぞれ `"copilot-pull-request-reviewer"` / `60`。

## GraphQL クエリ

```bash
gh api graphql \
  -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER" \
  -f reviewer="$REVIEWER" -F window="$WINDOW" \
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
              isResolved
              comments(first: 100) {
                nodes { createdAt }
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

## 判定ロジック（jq）

```jq
([.data.repository.pullRequest.reviewRequests.nodes[]
  | .requestedReviewer
  | select(. != null and (.login? // "") == $reviewer)] | length) as $requested
| ([.data.repository.pullRequest.reviews.nodes[]
    | select(.author.login == $reviewer and .state == "PENDING")] | length) as $pending
| ([.data.repository.pullRequest.reviewThreads.nodes[].comments.nodes[].createdAt
    | fromdateiso8601] | max // 0) as $latest
| ($window | tonumber) as $w
| if $requested > 0 then "REQUESTED"
  elif $pending > 0 then "PENDING"
  elif ($latest > 0 and (now - $latest) < $w) then "RECENT_COMMENT"
  else "" end
```

空文字 `""` が返れば「安定」、それ以外（`REQUESTED` / `PENDING` / `RECENT_COMMENT`）は「進行中」。

## CI ステータスの解釈

同じクエリで取得できる `statusCheckRollup` から CI の状態を判定する:

- `statusCheckRollup` が `null` → CI 未設定。CI チェックをスキップする（通過扱い）
- `statusCheckRollup.state`:
  - `SUCCESS` → 全チェック通過
  - `PENDING` / `EXPECTED` → チェック実行中
  - `FAILURE` / `ERROR` → チェック失敗

失敗したチェックの詳細は `statusCheckRollup.contexts.nodes[]` で確認できる。`CheckRun` の `conclusion` が `FAILURE` のものが失敗チェック。

## 使用時の注意

- 本チェックは 1 ショット。結果が「進行中」ならセッションを終了し、次回の呼び出しで再チェックする
- `reviewThreads` の `isResolved` フィールドもこのクエリで同時に取れるので、進行中でなかった場合は追加クエリ無しで `isResolved: false` の有無判定に進める
- `statusCheckRollup` も同じクエリで取れるので、CI 状態の判定にも追加クエリは不要
