---
name: task-loop-run
description: タスクフォルダからタスクを1つずつ取り出し、実装・コミット・PR作成・Copilotレビュー・修正・マージをループ実行するスキル。「タスクループを実行」「タスクを順番に実装してPRを出して」「自動でタスクを処理して」といった場面で使用する。
---

# Task Loop Run

`tasks/` フォルダのタスクファイルを順番に処理し、各タスクについて 実装 → コミット → PR → レビュー → 修正 → マージ のサイクルを自動実行する。

## 呼び出しモデル

外部ループ（`run-loop.sh`）は AI に **モードや状態を一切渡さない**。AI は毎回このスキルの指示に従い、`{tasksDir}/` の現在の状態から次に何をすべきか自己判定する。shell はタスクディレクトリの監視とレビューのポーリング待ちだけを行う。

状態ソース:
- **タスク配置**: `{tasksDir}/todo/` / `{tasksDir}/processing/` / `{tasksDir}/done/` / `{tasksDir}/failed/`
- **PR番号**: `{tasksDir}/processing/.pr_number`（`steps/pr.md` が書き出す）
- **修正回数**: `{tasksDir}/processing/.fix_count`（`steps/fix.md` がインクリメントする）
- **設定**: `task-loop-config.json`

> レビューのポーリング待ち・「レビュー進行中」判定はシェル側が担当する。AIセッション内で `sleep` によるポーリングや進行中チェックを行ってはならない。

## 自己判定フロー

起動したら以下の順で状態を確認し、対応するステップ列を実行する:

1. **`processing/` にタスクファイルが無い** → `{tasksDir}/todo/` から次のタスクを選び、
   - `steps/init.md` → `steps/implement.md` → `steps/self-review.md` → `steps/commit.md` → `steps/pr.md` → `steps/review-wait.md`
   - → **終了**

2. **`processing/` にタスクあり、`.pr_number` 無し** → 実装途中で中断されたとみなし、
   - `references/state-management.md` の中断復帰手順に従って適切なステップから再開
   - → **終了**

3. **`processing/` にタスクあり、`.pr_number` あり** → レビュー結果判定フローへ:
   - `steps/review-check.md` に従う
   - `.fix_count` と `task-loop-config.json` の `maxFixIterations` を読む
   - `.fix_count >= maxFixIterations` → 「best-effort マージ + failed 記録」フロー（`steps/error-recovery.md` の `fix_limit_exceeded` セクション）
   - 未解決スレッドあり → `steps/fix.md`（ここで `.fix_count` をインクリメント）
   - 未解決スレッドなし → `steps/merge.md` → `steps/update-state.md`
   - → **終了**

### ステップファイル一覧

| ファイル | 内容 |
|---------|------|
| `steps/init.md` | タスク初期化（ブランチ作成、状態更新） |
| `steps/implement.md` | 実装（コード変更、テスト実行） |
| `steps/self-review.md` | セルフレビュー（サブエージェントによる事前レビュー） |
| `steps/commit.md` | コミット（ステージング、メッセージ作成） |
| `steps/pr.md` | PR作成（プッシュ、PR本文生成、レビュアー設定） |
| `steps/review-wait.md` | レビュー待ち（外部ループが担当） |
| `steps/review-check.md` | レビュー結果の判定（fix/merge 分岐） |
| `steps/fix.md` | レビュー指摘修正 |
| `steps/merge.md` | PRマージ |
| `steps/update-state.md` | 状態更新（タスク完了記録） |
| `steps/loop-check.md` | ループ条件チェック |
| `steps/error-recovery.md` | エラーリカバリー |
| `steps/summary.md` | 終了サマリー出力 |
| `steps/session-export.md` | セッションレポートのMarkdown書き出し |

> **補足**: Copilot は `reviewDecision`（APPROVED / CHANGES_REQUESTED）を設定しない。
> レビューが提出されたかどうか（`latestReviews` の数の変化）を shell が検知し、
> コメント内容の分析（指摘の有無判断）は `review-check` モードで AI が行う。

## 前提条件

実行前に以下を確認する。満たされていない場合はユーザーに案内して停止する。

1. `gh` CLIが認証済みであること — `gh auth status` で確認
2. タスクディレクトリが存在すること — 設定の `tasksDir`（デフォルト: `tasks`）
3. `{tasksDir}/todo/` にタスクファイル（`.md`）が1つ以上あること
4. gitリポジトリであること、ワーキングツリーがクリーンであること

前提条件が整っていない場合は `task-loop-setup` スキルの使用を案内する。

## 設定の読み込み

リポジトリルートの `task-loop-config.json` を読み込む。ファイルが存在しない場合は全てデフォルト値を使用する。設定フォーマットとデフォルト値の詳細は `references/loop-config-format.md` を参照。

## Task.md の読み込み

`references/task-md-reading.md` の手順に従って Task.md を読み込む。

## 中断復帰チェック

ループ開始前に `{tasksDir}/processing/` にタスクファイルがあるか確認する。あれば中断からの復帰手順（`references/state-management.md`）に従って適切なステップから再開する。

## タスク発見

`references/task-discovery.md` の手順に従ってタスクを選択する。
