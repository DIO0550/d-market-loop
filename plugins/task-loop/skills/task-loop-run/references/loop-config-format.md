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
  "allowedCommands": ["pnpm test", "pnpm run lint"]
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
| `allowedCommands` | string[] | `[]` | Claudeセッションで許可するBashコマンド。完全一致で指定する。詳細は下記参照 |

## allowedCommands

Claudeセッションで実行を許可するBashコマンドを指定する。各コマンドは前方一致で評価される（例: `"git commit"` は `git commit -m "msg"` にもマッチする）。

`git` や `gh` を含め、必要なコマンドを全て列挙する。

許可は2層で適用される:
1. **PreToolUse hook** — 対話セッションでコマンドを自動許可
2. **run-loop.sh (`--allowedTools`)** — `claude -p` 非対話セッションでコマンドを許可

また、許可コマンド一覧は `run-loop.sh` 実行時にプロンプトへ自動注入され、Claudeがどのコマンドを使えるかを認識できる。

設定例:
```json
{
  "allowedCommands": [
    "git status",
    "git add",
    "git commit",
    "git push",
    "git checkout",
    "git switch",
    "git branch",
    "git diff",
    "git log",
    "gh pr create",
    "gh pr view",
    "gh pr merge",
    "gh api",
    "pnpm test",
    "pnpm run lint",
    "pnpm run build"
  ]
}
```

