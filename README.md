# d-market-loop

Claude Code 向けのプラグインマーケットプレイス。タスクの自動ループ実行を提供する。

## プラグイン

マーケットプレイスはプラグイン単位で機能を提供する。各プラグインは `plugins/` ディレクトリに配置され、`plugin.json` で定義される。

```
.claude-plugin/
  marketplace.json       # マーケットプレイス全体のメタデータ
plugins/
  task-loop/
    plugin.json          # プラグイン定義
    hooks/               # ライフサイクルフック
    skills/              # スキル群
```

### plugin.json

```json
{
  "name": "task-loop",
  "version": "1.0.0",
  "description": "長時間タスクの実行・監視・管理を行うプラグイン",
  "skills": "./skills",
  "hooks": "./hooks/hooks.json"
}
```

## task-loop

タスクファイルを順番に処理し、**実装 → コミット → PR → レビュー → 修正 → マージ** のサイクルを自動実行するプラグイン。

外部シェルスクリプト (`run-loop.sh`) が Claude CLI セッションを繰り返し起動し、タスクキュー (`tasks/todo/`) が空になるまで処理を続ける。

### ワークフロー概要

```
tasks/todo/001-xxx.md  →  processing/  →  done/ (or failed/)
                              │
              init → implement → commit → PR
                                           │
                              review-check → fix or merge
```

## スキル

プラグインは3つのスキルで構成される。各スキルは `skills/` 配下に `SKILL.md` として定義される。

| スキル | 説明 |
|--------|------|
| **task-loop-setup** | 初期セットアップ。設定ファイル・タスクフォルダ・ループスクリプトを配置する |
| **task-loop-doc** | タスクファイルの生成とプロジェクトコンテキスト (`Task.md`) の作成 |
| **task-loop-run** | タスクの自動実行。実装・コミット・PR・レビュー・マージをループ処理する |

### 利用順序

```
task-loop-setup  →  task-loop-doc  →  run-loop.sh (task-loop-run を繰り返し呼び出す)
```

1. **task-loop-setup**: 設定ヒアリング → `task-loop-config.json`・ディレクトリ・スクリプトを生成
2. **task-loop-doc**: 要件をタスクファイルに分割 → `tasks/todo/` に配置、`Task.md` を生成
3. **task-loop-run**: `run-loop.sh` 経由で自動実行

## task-loop-run

3つの実行モードを持ち、外部ループ (`run-loop.sh`) からモード別に呼び出される。

| モード | ステップ | 説明 |
|--------|----------|------|
| `implement` | init → implement → commit → pr → review-wait | タスク初期化から PR 作成まで |
| `review-check` | fix or merge → update-state | レビュー分析。指摘あり→修正、なし→マージ |
| `error` | error-recovery | エラー状態の記録と後処理 |

### ステップファイル

各ステップは `steps/` 配下に1ファイル1責務で分割されている。

| ファイル | 内容 |
|---------|------|
| `init.md` | タスク初期化（ブランチ作成、状態更新） |
| `implement.md` | 実装（コード変更、テスト実行） |
| `commit.md` | コミット（ステージング、メッセージ作成） |
| `pr.md` | PR 作成（プッシュ、PR 本文生成、レビュアー設定） |
| `review-wait.md` | レビュー待ち（外部ループが担当） |
| `fix.md` | レビュー指摘修正 |
| `merge.md` | PR マージ |
| `update-state.md` | 状態更新（タスク完了記録） |
| `loop-check.md` | ループ条件チェック |
| `error-recovery.md` | エラーリカバリー |
| `summary.md` | 終了サマリー出力 |
| `session-export.md` | セッションレポートの Markdown 書き出し |

### references

スキルが参照する仕様ドキュメント群。

| ファイル | 内容 |
|---------|------|
| `loop-config-format.md` | `task-loop-config.json` のスキーマ定義 |
| `state-management.md` | フォルダ・frontmatter・JSON の三重状態管理 |
| `task-discovery.md` | `tasks/todo/` からのタスク選択ルール |
| `task-md-reading.md` | `Task.md` の読み込み手順 |
| `task-file-format.md` | タスクファイル (`.md`) のフォーマット定義 |
| `task-md-format.md` | `Task.md` のフォーマット定義 |

### loop-config-format.md

`task-loop-config.json` のスキーマ。リポジトリルートに配置することで動作をカスタマイズできる。ファイルが存在しない場合は全てデフォルト値が使用される。

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
  "sessionLogsDir": "session-logs"
}
```

| フィールド | 型 | デフォルト | 説明 |
|-----------|------|-----------|------|
| `tasksDir` | string | `"tasks"` | タスクファイルのディレクトリ |
| `stateFile` | string | `"task-loop-state.json"` | 状態ファイルのパス |
| `planFile` | string | `"Task.md"` | プロジェクトコンテキストファイルのパス |
| `baseBranch` | string | `"main"` | ベースブランチ名 |
| `branchPrefix` | string | `"task/"` | タスクブランチ名のプレフィックス |
| `maxTasks` | number | `0` | 処理するタスクの最大数（0 = 無制限） |
| `stopOnError` | boolean | `true` | タスク失敗時にループを停止するか |
| `timeLimitMinutes` | number | `0` | ループの制限時間（分、0 = 無制限） |
| `reviewer` | string | `"copilot"` | PR のレビュアー（`"copilot"` で GitHub Copilot を指定） |
| `mergeStrategy` | string | `"squash"` | マージ戦略: `"squash"` / `"merge"` / `"rebase"` |
| `deleteBranchAfterMerge` | boolean | `true` | マージ後にブランチを削除するか |
| `reviewPollIntervalSeconds` | number | `30` | レビュー結果のポーリング間隔（秒） |
| `reviewMaxWaitMinutes` | number | `30` | レビュー待ちの最大時間（分） |
| `maxFixIterations` | number | `3` | レビュー指摘修正の最大回数 |
| `autoMergeWithoutReview` | boolean | `false` | レビュータイムアウト時に自動マージするか |
| `prBodyFooter` | string | `"Automated by task-loop-run"` | PR 本文のフッター |
| `sessionLogsDir` | string | `"session-logs"` | セッションログの出力ディレクトリ |
