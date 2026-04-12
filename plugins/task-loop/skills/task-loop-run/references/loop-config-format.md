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
  "reviewMaxWaitMinutes": 30,
  "maxFixIterations": 3,
  "autoMergeWithoutReview": false,
  "prBodyFooter": "Automated by task-loop-run",
  "sessionLogsDir": "session-logs"
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
| `reviewPollIntervalSeconds` | number | `30` | レビュー結果のポーリング間隔（秒） |
| `reviewMaxWaitMinutes` | number | `30` | レビュー待ちの最大時間（分） |
| `maxFixIterations` | number | `3` | レビュー指摘修正の最大回数 |
| `autoMergeWithoutReview` | boolean | `false` | レビュータイムアウト時に自動マージするか |
| `prBodyFooter` | string | `"Automated by task-loop-run"` | PR本文のフッター |
| `sessionLogsDir` | string | `"session-logs"` | セッションログの出力ディレクトリ（リポジトリルートからの相対パス） |

