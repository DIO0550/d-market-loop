# ループ設定フォーマット

リポジトリルートに `task-loop-config.json` を配置することで動作をカスタマイズできる。
ファイルが存在しない場合は全てデフォルト値が使用される。

## スキーマ

```json
{
  "tasksDir": "tasks",
  "planFile": "Task.md",
  "baseBranch": "main",
  "branchPrefix": "task/",
  "maxTasks": 0,
  "stopOnError": true,
  "timeLimitMinutes": 0,
  "reviewer": "copilot-pull-request-reviewer",
  "mergeStrategy": "squash",
  "deleteBranchAfterMerge": true,
  "reviewPollIntervalSeconds": 30,
  "reviewStabilizeIntervalSeconds": 15,
  "reviewStabilizeMaxSeconds": 300,
  "reviewInProgressWindowSeconds": 30,
  "maxFixIterations": 3,
  "prBodyFooter": "Automated by task-loop-run",
  "sessionLogsDir": "session-logs",
  "allowedCommands": []
}
```

## フィールド詳細

| フィールド | 型 | デフォルト | 説明 |
|-----------|------|-----------|------|
| `tasksDir` | string | `"tasks"` | タスクファイルのディレクトリ（リポジトリルートからの相対パス） |
| `planFile` | string | `"Task.md"` | プロジェクトコンテキストファイルのパス（リポジトリルートからの相対パス） |
| `baseBranch` | string | `"main"` | ベースブランチ名 |
| `branchPrefix` | string | `"task/"` | タスクブランチ名のプレフィックス |
| `maxTasks` | number | `0` | 処理するタスクの最大数。0 = 無制限 |
| `stopOnError` | boolean | `true` | タスク失敗時にループを停止するか |
| `timeLimitMinutes` | number | `0` | ループの制限時間（分）。0 = 無制限 |
| `reviewer` | string | `"copilot-pull-request-reviewer"` | PRのレビュアー。`"copilot-pull-request-reviewer"` でGitHub Copilotを指定 |
| `mergeStrategy` | string | `"squash"` | マージ戦略: `"squash"`, `"merge"`, `"rebase"` |
| `deleteBranchAfterMerge` | boolean | `true` | マージ後にブランチを削除するか |
| `reviewPollIntervalSeconds` | number | `30` | レビュー結果のポーリング間隔（秒）。shell は無限にポーリングする（タイムアウト無し） |
| `reviewStabilizeIntervalSeconds` | number | `15` | レビュー進行中判定のポーリング間隔（秒） |
| `reviewStabilizeMaxSeconds` | number | `300` | 安定化待ちの上限（秒）。上限に達した場合は現状のまま AI に引き継ぐ |
| `reviewInProgressWindowSeconds` | number | `30` | 直近この秒数以内に reviewThread コメントが追加されていたら「進行中」とみなす。Copilot の追加投稿による race condition を防ぐ |
| `maxFixIterations` | number | `3` | レビュー指摘修正の最大回数。超えると `steps/review-check.md` が best-effort マージ → failed 記録フローに入る |
| `prBodyFooter` | string | `"Automated by task-loop-run"` | PR本文のフッター |
| `sessionLogsDir` | string | `"session-logs"` | セッションログの出力ディレクトリ（リポジトリルートからの相対パス） |
| `allowedCommands` | string[] | `[]` | プロジェクト固有の追加許可コマンド。git/gh/tsc/eslint/pnpm 基本コマンド等は run-loop.sh のデフォルトで許可済みのため、ここには追加で必要なものだけ記載する。詳細は `task-loop-setup/references/allowed-commands.md` を参照 |

