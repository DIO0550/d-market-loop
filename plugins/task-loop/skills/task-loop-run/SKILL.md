---
name: task-loop-run
description: タスクフォルダからタスクを1つずつ取り出し、実装・コミット・PR作成・Copilotレビュー・修正・マージをループ実行するスキル。「タスクループを実行」「タスクを順番に実装してPRを出して」「自動でタスクを処理して」といった場面で使用する。
---

# Task Loop Run

`tasks/` フォルダのタスクファイルを順番に処理し、各タスクについて 実装 → コミット → PR → レビュー → 修正 → マージ のサイクルを自動実行する。

## 実行モード

外部ループ（`run-loop.sh`）からモード別に呼び出される。レビューのポーリング待ちはシェル側が担当し、AIセッション内では `sleep` によるポーリングを行わない。

| モード | 読み込むステップファイル | 説明 |
|--------|------------------------|------|
| `implement` | `init` → `implement` → `commit` → `pr` → `review-wait` | タスク初期化〜PR作成。PR作成後に終了 |
| `review-check` | `fix` or `merge` → `update-state` | レビュー分析。指摘あり→修正、なし→マージ |
| `error` | `error-recovery` | エラー状態の記録と後処理 |

**実行手順**: モードに対応するステップファイルを `steps/` から順に読み込み、その指示に従って処理する。各ステップは1ファイル1責務で分割されている。

### ステップファイル一覧

| ファイル | 内容 |
|---------|------|
| `steps/init.md` | タスク初期化（ブランチ作成、状態更新） |
| `steps/implement.md` | 実装（コード変更、テスト実行） |
| `steps/commit.md` | コミット（ステージング、メッセージ作成） |
| `steps/pr.md` | PR作成（プッシュ、PR本文生成、レビュアー設定） |
| `steps/review-wait.md` | レビュー待ち（外部ループが担当） |
| `steps/fix.md` | レビュー指摘修正 |
| `steps/merge.md` | PRマージ |
| `steps/update-state.md` | 状態更新（タスク完了記録） |
| `steps/loop-check.md` | ループ条件チェック |
| `steps/error-recovery.md` | エラーリカバリー |
| `steps/summary.md` | 終了サマリー出力 |

> **補足**: Copilot は `reviewDecision`（APPROVED / CHANGES_REQUESTED）を設定しない。
> レビューが提出されたかどうか（`latestReviews` の数の変化）を shell が検知し、
> コメント内容の分析（指摘の有無判断）は `review-check` モードで AI が行う。

## 前提条件

実行前に以下を確認する。満たされていない場合はユーザーに案内して停止する。

1. `gh` CLIが認証済みであること — `gh auth status` で確認
2. タスクディレクトリが存在すること — 設定の `tasksDir`（デフォルト: `tasks`）
3. タスクディレクトリにpendingのタスクファイル（`.md`）が1つ以上あること
4. gitリポジトリであること、ワーキングツリーがクリーンであること

前提条件が整っていない場合は `task-loop-setup` スキルの使用を案内する。

## 設定の読み込み

リポジトリルートの `task-loop-config.json` を読み込む。ファイルが存在しない場合は全てデフォルト値を使用する。

デフォルト値:
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
  "prBodyFooter": "Automated by task-loop-run"
}
```

設定フォーマットの詳細は `references/loop-config-format.md` を参照。

## Task.md の読み込み

設定の `planFile`（デフォルト: `Task.md`）を確認する。

1. ファイルが存在する場合:
   - Task.md を全文読み込む
   - **Context セクション** から以下の情報を以降のタスク処理で活用する:
     - **Tech Stack** — 技術スタックを実装時に遵守する
     - **Architecture** — アーキテクチャに沿った実装をする
     - **Constraints** — 制約条件を守る
     - **Shared Context** — タスク間の連携情報を参照し、一貫した実装を行う
     - **Notes** — リスク、規約、注意点を意識する
   - **カンバンセクション** から現在のタスク状態を把握する
2. ファイルが存在しない場合:
   - 警告なしでスキップする（後方互換性を維持）
   - Task.md の更新も全てスキップする
   - タスクファイルの内容のみに基づいて実装する

## 中断復帰チェック

ループ開始前に `task-loop-state.json` を確認する。`status: "in_progress"` のタスクがあれば、中断からの復帰手順（`references/state-management.md`）に従って適切なステップから再開する。

## タスク発見

1. `{tasksDir}/*.md` を取得する
2. ファイル名の昇順（辞書順）でソートする
3. 各ファイルのfrontmatterを読み、`status` を確認する
4. `status` が未設定または `pending` のタスクを「未処理」とする
5. `completed`、`failed`、`skipped` のタスクはスキップする
6. 最初の未処理タスクを選択する
7. 未処理タスクがなければループ終了（`steps/summary.md` の終了サマリーへ）
