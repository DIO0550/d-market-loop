# 状態管理

## 概要

状態は3箇所で管理する:

1. **フォルダ構造** — タスクファイルの所在フォルダが状態を表す（`todo/`、`processing/`、`done/`、`failed/`）
2. **タスクファイルのfrontmatter** — 個別タスクの補足情報（`assignedAt`、`completedAt`、`prUrl` 等）
3. **task-loop-state.json** — 全体の実行状態と履歴（プログラム的な管理用）

## task-loop-state.json フォーマット

```json
{
  "version": 1,
  "startedAt": "2026-03-22T10:00:00Z",
  "lastUpdatedAt": "2026-03-22T10:30:00Z",
  "tasksCompleted": 2,
  "tasksFailed": 0,
  "tasksSkipped": 0,
  "tasks": {
    "001-add-auth.md": {
      "status": "completed",
      "branch": "task/001-add-auth",
      "prNumber": 42,
      "prUrl": "https://github.com/owner/repo/pull/42",
      "startedAt": "2026-03-22T10:00:00Z",
      "completedAt": "2026-03-22T10:15:00Z",
      "reviewIterations": 1
    },
    "002-setup-database.md": {
      "status": "completed",
      "branch": "task/002-setup-database",
      "prNumber": 43,
      "prUrl": "https://github.com/owner/repo/pull/43",
      "startedAt": "2026-03-22T10:15:00Z",
      "completedAt": "2026-03-22T10:30:00Z",
      "reviewIterations": 0
    }
  }
}
```

## 状態遷移

```
todo/ ──→ processing/ ──→ done/
               │
               ├──→ failed/
               │
               └──→ todo/（skipped: 手動で戻す）
```

## 状態の更新タイミング

| タイミング | フォルダ移動 | タスクファイル frontmatter | state file |
|-----------|-------------|--------------------------|------------|
| タスク開始 | `todo/` → `processing/` | `assignedAt` 設定 | タスクエントリ追加、`status: "in_progress"` |
| PR作成 | — | `prUrl` 設定 | `prNumber`, `prUrl` 設定。`processing/.pr_number` にPR番号を書き出す |
| タスク完了 | `processing/` → `done/` | `completedAt` 設定 | `status: "completed"`, カウンタ更新 |
| タスク失敗 | `processing/` → `failed/` | — | `status: "failed"`, カウンタ更新 |

## 中断からの復帰

Claude セッションが中断された場合、次回起動時に以下の手順で復帰する:

1. `{tasksDir}/processing/` にタスクファイルがあるか確認する
2. タスクファイルがあれば（= 中断されたタスク）:
   - `task-loop-state.json` から該当タスクの情報を読む
   - `git branch -a` でタスクブランチの存在を確認
   - `gh pr list --head {branch}` でPRの存在を確認
   - PRが存在する場合 → レビュー待ちステップから再開
   - PRが存在しない場合 → ブランチに未コミットの変更があるか確認
     - 変更あり → コミットステップから再開
     - 変更なし → 実装ステップから再開
3. `processing/` が空なら → 通常のタスク発見フロー（`todo/` からピック）に進む

## .gitignore

`task-loop-state.json` はリポジトリにコミットしない。セットアップ時に `.gitignore` に追加する:

```
task-loop-state.json
```
