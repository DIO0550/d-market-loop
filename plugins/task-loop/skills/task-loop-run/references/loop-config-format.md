# ループ設定フォーマット

リポジトリルートに `task-loop-config.json` を配置することで動作をカスタマイズできる。
ファイルが存在しない場合は全てデフォルト値が使用される。

## スキーマ

```json
{
  "tasksDir": "tasks",
  "stateFile": "task-loop-state.json",
  "planFile": "Task.md",
  "baseBranch": "main",
  "branchPrefix": "task/",
  "maxTasks": 0,
  "stopOnError": true,
  "timeLimitMinutes": 0,
  "reviewer": "copilot",
  "mergeStrategy": "squash",
  "deleteBranchAfterMerge": true,
  "reviewPollIntervalSeconds": 30,
  "reviewMaxWaitMinutes": 30,
  "maxFixIterations": 3,
  "autoMergeWithoutReview": false,
  "prBodyFooter": "Automated by task-loop-run",
  "sessionLogsDir": "session-logs",
  "allowedCommands": ["pnpm:*"]
}
```

## フィールド詳細

| フィールド | 型 | デフォルト | 説明 |
|-----------|------|-----------|------|
| `tasksDir` | string | `"tasks"` | タスクファイルのディレクトリ（リポジトリルートからの相対パス） |
| `stateFile` | string | `"task-loop-state.json"` | 状態ファイルのパス |
| `planFile` | string | `"Task.md"` | プロジェクトコンテキストファイルのパス（リポジトリルートからの相対パス） |
| `baseBranch` | string | `"main"` | ベースブランチ名 |
| `branchPrefix` | string | `"task/"` | タスクブランチ名のプレフィックス |
| `maxTasks` | number | `0` | 処理するタスクの最大数。0 = 無制限 |
| `stopOnError` | boolean | `true` | タスク失敗時にループを停止するか |
| `timeLimitMinutes` | number | `0` | ループの制限時間（分）。0 = 無制限 |
| `reviewer` | string | `"copilot"` | PRのレビュアー。`"copilot"` でGitHub Copilotを指定 |
| `mergeStrategy` | string | `"squash"` | マージ戦略: `"squash"`, `"merge"`, `"rebase"` |
| `deleteBranchAfterMerge` | boolean | `true` | マージ後にブランチを削除するか |
| `reviewPollIntervalSeconds` | number | `30` | レビュー結果のポーリング間隔（秒） |
| `reviewMaxWaitMinutes` | number | `30` | レビュー待ちの最大時間（分） |
| `maxFixIterations` | number | `3` | レビュー指摘修正の最大回数 |
| `autoMergeWithoutReview` | boolean | `false` | レビュータイムアウト時に自動マージするか |
| `prBodyFooter` | string | `"Automated by task-loop-run"` | PR本文のフッター |
| `sessionLogsDir` | string | `"session-logs"` | セッションログの出力ディレクトリ（リポジトリルートからの相対パス） |
| `allowedCommands` | string[] | `[]` | Claudeセッションで追加で許可するBashコマンド。`--allowedTools` の `Bash()` に追加される。詳細は下記参照 |

## allowedCommands

Claudeセッションで実行を許可するコマンドを指定する。`git` と `gh` は常に許可されるため指定不要。

各要素は `--allowedTools` の `Bash()` 記法に対応する:

| 記法 | 意味 | 例 |
|------|------|-----|
| `"pnpm:*"` | pnpmの全サブコマンドを許可 | `pnpm test`, `pnpm install`, `pnpm run build` |
| `"pnpm test"` | 特定のコマンドのみ許可 | `pnpm test` だけ |
| `"npm:*"` | npmの全サブコマンドを許可 | `npm test`, `npm run lint` |
| `"make:*"` | makeの全ターゲットを許可 | `make build`, `make test` |

設定例:
```json
{
  "allowedCommands": ["pnpm:*"]
}
```

```json
{
  "allowedCommands": ["npm test", "npm run lint", "npm run build"]
}
```

