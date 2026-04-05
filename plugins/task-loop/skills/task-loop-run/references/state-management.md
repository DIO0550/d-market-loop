# 状態管理

## 概要

状態は2箇所で管理する:

1. **フォルダ構造** — タスクファイルの所在フォルダが状態を表す（`todo/`、`processing/`、`done/`、`failed/`）
2. **タスクファイルのfrontmatter** — 個別タスクの補足情報（`assignedAt`、`completedAt`、`prUrl`、`prNumber`、`branch` 等）

## 状態遷移

```
todo/ ──→ processing/ ──→ done/
               │
               ├──→ failed/
               │
               └──→ todo/（skipped: 手動で戻す）
```

## 状態の更新タイミング

| タイミング | フォルダ移動 | タスクファイル frontmatter |
|-----------|-------------|--------------------------|
| タスク開始 | `todo/` → `processing/` | `assignedAt` 設定、`branch` 設定 |
| PR作成 | — | `prUrl`、`prNumber` 設定。`processing/.pr_number` にPR番号を書き出す |
| タスク完了 | `processing/` → `done/` | `completedAt` 設定 |
| タスク失敗 | `processing/` → `failed/` | — |

## 進捗の集計

全体の進捗はフォルダ内のファイル数で算出する:

- 完了数: `done/` 内の `.md` ファイル数
- 失敗数: `failed/` 内の `.md` ファイル数
- 残タスク: `todo/` 内の `.md` ファイル数

## 中断からの復帰

Claude セッションが中断された場合、次回起動時に以下の手順で復帰する:

1. `{tasksDir}/processing/` にタスクファイルがあるか確認する
2. タスクファイルがあれば（= 中断されたタスク）:
   - タスクファイルのfrontmatterから `branch`、`prUrl`、`prNumber` を読む
   - `git branch -a` でタスクブランチの存在を確認
   - `gh pr list --head {branch}` でPRの存在を確認
   - PRが存在する場合 → レビュー待ちステップから再開
   - PRが存在しない場合 → ブランチに未コミットの変更があるか確認
     - 変更あり → コミットステップから再開
     - 変更なし → 実装ステップから再開
3. `processing/` が空なら → 通常のタスク発見フロー（`todo/` からピック）に進む
