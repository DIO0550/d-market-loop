# 状態管理

## 概要

状態は3箇所で管理する:

1. **タスクファイルのfrontmatter** — 個別タスクの状態（人間が直接確認可能）
2. **task-loop-state.json** — 全体の実行状態と履歴（プログラム的な管理用）
3. **Task.md** — カンバン形式のタスクダッシュボード（Todo/Processing/Done/Failed の4セクションで進捗を可視化）

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
pending ──→ in_progress ──→ completed
                │
                ├──→ failed
                │
                └──→ skipped（手動設定のみ）
```

## 状態の更新タイミング

| タイミング | タスクファイル | state file | Task.md |
|-----------|--------------|------------|---------|
| タスク開始 | `status: in_progress`, `assignedAt` 設定 | タスクエントリ追加、`status: "in_progress"` | Todo → Processing に移動（StartedAt, Branch, Step 追加） |
| PR作成 | `prUrl` 設定 | `prNumber`, `prUrl` 設定 | — |
| レビュー待ち | — | — | Step を `reviewing` に更新（AIセッション終了、外部ループがポーリング） |
| レビュー修正 | — | — | Step を `fixing` に更新（新しいAIセッションで修正） |
| マージ中 | — | — | Step を `merging` に更新 |
| タスク完了 | `status: completed`, `completedAt` 設定 | `status: "completed"`, カウンタ更新 | Processing → Done に移動（CompletedAt, PR 追加） |
| タスク失敗 | `status: failed` | `status: "failed"`, カウンタ更新 | Processing → Failed に移動（FailedAt, Reason 追加） |

## 中断からの復帰

Claude セッションが中断された場合、次回起動時に以下の手順で復帰する:

1. `task-loop-state.json` を読み込む
2. `status: "in_progress"` のタスクを探す
3. 該当タスクがあれば:
   - `git branch -a` でタスクブランチの存在を確認
   - `gh pr list --head {branch}` でPRの存在を確認
   - PRが存在する場合 → レビュー待ちステップから再開
   - PRが存在しない場合 → ブランチに未コミットの変更があるか確認
     - 変更あり → コミットステップから再開
     - 変更なし → 実装ステップから再開
4. 該当タスクがなければ → 通常のタスク発見フローに進む

## .gitignore

`task-loop-state.json` はリポジトリにコミットしない。セットアップ時に `.gitignore` に追加する:

```
task-loop-state.json
```

タスクファイルのfrontmatter更新（status変更）はコミットして問題ない。
