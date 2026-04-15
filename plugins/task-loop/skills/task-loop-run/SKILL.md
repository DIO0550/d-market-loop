---
name: task-loop-run
description: タスクフォルダからタスクを1つずつ取り出し、実装・コミット・PR作成・Copilotレビュー・修正・マージをループ実行するスキル。「タスクループを実行」「タスクを順番に実装してPRを出して」「自動でタスクを処理して」といった場面で使用する。
---

# Task Loop Run

`tasks/` フォルダのタスクファイルを順番に処理し、各タスクについて 実装 → コミット → PR → レビュー → 修正 → マージ のサイクルを自動実行する。

## 呼び出しモデル

このスキルは **毎回の呼び出しで 1 つだけ行動する**。毎回このスキルの指示に従い、`{tasksDir}/` 配下のファイル状態と GitHub 上の PR 状態（GraphQL）の「いま観測できる事実」だけから次に何をすべきか自己判定する。

状態ソース:
- **タスク配置**: `{tasksDir}/todo/` / `{tasksDir}/processing/` / `{tasksDir}/done/` / `{tasksDir}/failed/`
- **PR番号**: `{tasksDir}/processing/.pr_number`（`steps/pr.md` が書き出す）
- **修正回数**: `{tasksDir}/processing/.fix_count`（`steps/fix.md` がインクリメントする）
- **設定**: `task-loop-config.json`
- **PR の GraphQL 状態**: `gh api graphql` で取得する `reviewThreads` / `reviewRequests` / `reviews`

> `sleep` による能動的ポーリングは禁止。行動できる状態でない（例: レビュー進行中）ときは何もせずセッションを終了する。次回の呼び出し時に改めて状態を観測する。

## 自己判定フロー

起動したら以下の順で状態を確認し、対応するステップ列を実行する:

1. **`processing/` にタスクファイルが無い** → `{tasksDir}/todo/` から次のタスクを選び、
   - `steps/init.md` → `steps/implement.md` → `steps/self-review.md` → `steps/commit.md` → `steps/pr.md` → `steps/review-wait.md`
   - → **終了**

2. **`processing/` にタスクあり、`.pr_number` 無し** → 実装途中で中断されたとみなし、
   - `references/state-management.md` の中断復帰手順に従って適切なステップから再開
   - → **終了**

3. **`processing/` にタスクあり、`.pr_number` あり** → レビュー結果判定フローへ。`steps/review-check.md` に従い、以下の **3a / 3b / 3c / 3d のいずれか一つだけ** を実行して即終了する:

   - **3a**: `.fix_count >= maxFixIterations` → 「best-effort マージ + failed 記録」フロー（`steps/error-recovery.md` の `fix_limit_exceeded` セクション） → **終了**
   - **3b**: レビュー進行中（`references/copilot-in-progress-check.md` の条件にヒット）→ **何もせず即終了**。`processing/` を残したまま、`.fix_count` も触らない
   - **3c**: レビュー安定・未解決スレッドあり → `steps/fix.md` の全手順（`.fix_count` インクリメントまで）→ **このセッションは即終了**。⚠️ fix.md 完了後に `reviewThreads` を再取得したり `steps/merge.md` に進んではならない。push により HEAD が変わっており、新しいレビューが届くのは次回呼び出し時
   - **3d**: レビュー安定・未解決スレッドなし → `steps/merge.md` → `steps/update-state.md` → **終了**

### ステップファイル一覧

| ファイル | 内容 |
|---------|------|
| `steps/init.md` | タスク初期化（ブランチ作成、状態更新） |
| `steps/implement.md` | 実装（コード変更、テスト実行） |
| `steps/self-review.md` | セルフレビュー（サブエージェントによる事前レビュー） |
| `steps/commit.md` | コミット（ステージング、メッセージ作成） |
| `steps/pr.md` | PR作成（プッシュ、PR本文生成、レビュアー設定） |
| `steps/review-wait.md` | レビュー待ち（AI セッションを終了するだけ） |
| `steps/review-check.md` | レビュー結果の判定（fix/merge 分岐） |
| `steps/fix.md` | レビュー指摘修正 |
| `steps/merge.md` | PRマージ |
| `steps/update-state.md` | 状態更新（タスク完了記録） |
| `steps/loop-check.md` | ループ条件チェック |
| `steps/error-recovery.md` | エラーリカバリー |
| `steps/summary.md` | 終了サマリー出力 |
| `steps/session-export.md` | セッションレポートのMarkdown書き出し |

> **補足**: Copilot は `reviewDecision`（APPROVED / CHANGES_REQUESTED）を設定しない。
> レビューが進行中かどうかの判定は `references/copilot-in-progress-check.md`、
> 未解決コメントの有無判断は `steps/review-check.md` で行う。

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
