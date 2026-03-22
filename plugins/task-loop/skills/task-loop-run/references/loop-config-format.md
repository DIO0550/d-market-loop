# ループ設定フォーマット

リポジトリルートに `task-loop-config.json` を配置することで動作をカスタマイズできる。
ファイルが存在しない場合は全てデフォルト値が使用される。

## スキーマ

```json
{
  "tasksDir": "tasks",
  "stateFile": "task-loop-state.json",
  "planFile": "task-loop-plan.md",
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
  "prBodyFooter": "Automated by task-loop-run"
}
```

## フィールド詳細

| フィールド | 型 | デフォルト | 説明 |
|-----------|------|-----------|------|
| `tasksDir` | string | `"tasks"` | タスクファイルのディレクトリ（リポジトリルートからの相対パス） |
| `stateFile` | string | `"task-loop-state.json"` | 状態ファイルのパス |
| `planFile` | string | `"task-loop-plan.md"` | ループ全体計画書のファイルパス（リポジトリルートからの相対パス） |
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

## ループ条件

ループは以下のいずれかの条件で終了する:

1. **全タスク完了**: pendingのタスクがなくなった
2. **maxTasks到達**: 指定した数のタスクを処理した
3. **timeLimitMinutes超過**: 制限時間を超えた
4. **エラー発生 + stopOnError**: タスクが失敗し、stopOnErrorがtrue

## 使用例

### 最小設定（デフォルトで十分な場合）

`task-loop-config.json` を作成しない。

### 1タスクずつ処理（外部ループ用）

```json
{
  "maxTasks": 1
}
```

### 人間のレビュアーを使用

```json
{
  "reviewer": "username",
  "reviewMaxWaitMinutes": 60
}
```

### エラーを無視して全タスク処理

```json
{
  "stopOnError": false,
  "maxTasks": 0
}
```
