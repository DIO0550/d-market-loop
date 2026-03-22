---
name: task-loop-run
description: タスクフォルダからタスクを1つずつ取り出し、実装・コミット・PR作成・Copilotレビュー・修正・マージをループ実行するスキル。「タスクループを実行」「タスクを順番に実装してPRを出して」「自動でタスクを処理して」といった場面で使用する。
---

# Task Loop Run

`tasks/` フォルダのタスクファイルを順番に処理し、各タスクについて 実装 → コミット → PR → レビュー → 修正 → マージ のサイクルを自動実行する。

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

設定フォーマットの詳細は `references/loop-config-format.md` を参照。

## 計画書の読み込み

設定の `planFile`（デフォルト: `task-loop-plan.md`）を確認する。

1. ファイルが存在する場合:
   - 計画書を全文読み込む
   - 以下の情報を以降のタスク処理で活用する:
     - **Project Context** — 技術スタック、アーキテクチャ、制約条件を実装時に遵守する
     - **Shared Context** — タスク間の連携情報を参照し、一貫した実装を行う
     - **Coding Conventions** — コーディング規約に従う
     - **Risks & Notes** — リスクと注意点を意識する
2. ファイルが存在しない場合:
   - 警告なしでスキップする（後方互換性を維持）
   - タスクファイルの内容のみに基づいて実装する

計画書フォーマットの詳細は `references/loop-plan-format.md` を参照。

## 中断復帰チェック

ループ開始前に `task-loop-state.json` を確認する。`status: "in_progress"` のタスクがあれば、中断からの復帰手順（`references/state-management.md`）に従って適切なステップから再開する。

## タスク発見

1. `{tasksDir}/*.md` を取得する
2. ファイル名の昇順（辞書順）でソートする
3. 各ファイルのfrontmatterを読み、`status` を確認する
4. `status` が未設定または `pending` のタスクを「未処理」とする
5. `completed`、`failed`、`skipped` のタスクはスキップする
6. 最初の未処理タスクを選択する
7. 未処理タスクがなければループ終了（終了サマリーへ）

## メインループ

選択したタスクに対して以下のステップを実行する。

### Step 1: タスク初期化

1. タスクファイルを全文読み込む
2. frontmatterから `title`、`commitPrefix` を取得する（titleがない場合はファイル名のハイフン区切り部分を使用）
3. ベースブランチが最新であることを確認する:
   ```bash
   git checkout {baseBranch}
   git pull origin {baseBranch}
   ```
4. タスク用ブランチを作成する:
   ```bash
   git checkout -b {branchPrefix}{ファイル名から拡張子を除いたもの}
   ```
   例: `task/001-add-auth`
5. タスクファイルのfrontmatterを `status: in_progress` に更新、`assignedAt` に現在時刻を設定
6. `task-loop-state.json` にタスクエントリを追加（status: "in_progress"、startedAt）

### Step 2: 実装

1. タスクファイルの Description、Requirements、Files to Modify、Acceptance Criteria を読む
2. 計画書が読み込まれている場合:
   - Project Context の Tech Stack・Architecture・Constraints に従う
   - Shared Context を確認し、先行タスクとの整合性を維持する
   - Coding Conventions に従ったコードを書く
3. タスクの内容に従って実装を行う
   - コードの読み取り、ファイルの作成・編集、必要に応じてコマンド実行
3. タスクファイルに Test Command が指定されている場合:
   - テストを実行する
   - テストが失敗した場合は修正して再実行する
   - 3回修正してもテストが通らない場合はエラーとして扱う（エラーリカバリーへ）

### Step 3: コミット

1. 変更をステージングする:
   ```bash
   git add -A
   ```
2. コミットメッセージを作成する:
   - フォーマット: `{commitPrefix}: {title}`
   - commitPrefixはタスクファイルのfrontmatterから取得（デフォルト: `feat`）
   - 例: `feat: 認証モジュールを追加する`
3. コミットを実行する:
   ```bash
   git commit -m "{コミットメッセージ}"
   ```

### Step 4: PR作成

1. ブランチをプッシュする:
   ```bash
   git push -u origin {ブランチ名}
   ```
2. PR本文を生成する:
   - タスクの Description を要約
   - 変更内容の箇条書き
   - テスト方法（Test Command があれば記載）
   - フッター（設定の `prBodyFooter`）
3. PRを作成する:
   ```bash
   gh pr create --title "{commitPrefix}: {title}" --body "{PR本文}" --base {baseBranch}
   ```
4. レビュアーを設定する:
   ```bash
   gh pr edit {PR番号} --add-reviewer {reviewer}
   ```
5. PR番号とURLを記録する
6. タスクファイルのfrontmatterに `prUrl` を設定
7. `task-loop-state.json` を更新（prNumber、prUrl）

### Step 5: レビュー待ち

1. レビュー結果をポーリングする:
   ```bash
   gh pr view {PR番号} --json reviews,latestReviews,reviewDecision
   ```
2. レスポンスを解析する:
   - `reviewDecision` が `"APPROVED"` → Step 7（マージ）へ
   - `reviewDecision` が `"CHANGES_REQUESTED"` → Step 6（修正）へ
   - latestReviews にレビューがあり、コメントに修正指摘が含まれる → Step 6（修正）へ
   - レビューがまだない → 待機して再ポーリング
3. 待機方法:
   ```bash
   sleep {reviewPollIntervalSeconds}
   ```
4. `reviewMaxWaitMinutes` を超えた場合:
   - `autoMergeWithoutReview` が `true` → Step 7（マージ）へ
   - `autoMergeWithoutReview` が `false` → ユーザーに通知して次のタスクへ

### Step 6: レビュー指摘修正

1. PRのレビューコメントを取得する:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{PR番号}/comments
   gh pr view {PR番号} --json reviews
   ```
2. 各コメントの指摘内容を解析する
3. 指摘に対して修正を実装する
4. 修正をコミットする:
   ```bash
   git add -A
   git commit -m "fix: address review comments for {title}"
   git push
   ```
5. 修正回数をカウントし、`maxFixIterations` に達した場合:
   - タスクの状態を `"needs_manual_review"` としてユーザーに通知
   - `stopOnError` が `true` → ループ終了
   - `stopOnError` が `false` → 次のタスクへ
6. まだ上限に達していない場合 → Step 5（レビュー待ち）に戻る

### Step 7: マージ

1. PRをマージする:
   ```bash
   gh pr merge {PR番号} --{mergeStrategy} --delete-branch
   ```
   ※ `deleteBranchAfterMerge` が `false` の場合は `--delete-branch` を省略
2. マージが失敗した場合（コンフリクト等）:
   - リベースを試みる:
     ```bash
     git fetch origin {baseBranch}
     git rebase origin/{baseBranch}
     ```
   - リベース成功 → プッシュしてマージを再試行
   - リベース失敗 → エラーリカバリーへ
3. ベースブランチに戻る:
   ```bash
   git checkout {baseBranch}
   git pull origin {baseBranch}
   ```

### Step 8: 状態更新

1. タスクファイルのfrontmatterを更新:
   - `status: completed`
   - `completedAt` に現在時刻を設定
2. `task-loop-state.json` を更新:
   - タスクの `status` を `"completed"` に
   - `completedAt` を設定
   - `tasksCompleted` カウンタを+1
   - `lastUpdatedAt` を更新
3. 状態更新をコミットする:
   ```bash
   git add {タスクファイル} {stateFile}
   git commit -m "chore: mark {ファイル名} as completed"
   git push origin {baseBranch}
   ```

### Step 9: ループ条件チェック

以下の条件を順にチェックし、いずれかに該当すればループを終了する:

1. **残タスクなし**: 未処理のタスクファイルがない → 終了
2. **maxTasks到達**: 処理したタスク数 >= `maxTasks`（maxTasks > 0 の場合） → 終了
3. **時間制限超過**: ループ開始からの経過時間 > `timeLimitMinutes`（timeLimitMinutes > 0 の場合） → 終了

条件に該当しなければ、タスク発見に戻り次のタスクを処理する。

## エラーリカバリー

| エラー | 対処 |
|--------|------|
| 実装時にテストが通らない | 3回まで修正を試みる。それでも失敗 → `status: failed` に更新 |
| git push が失敗 | 認証を確認、1回リトライ |
| PR作成が失敗 | 同名ブランチのPRが既にあるか確認。あれば再利用 |
| レビュータイムアウト | `autoMergeWithoutReview` の設定に従う |
| 修正上限到達 | `needs_manual_review` として記録 |
| マージコンフリクト | リベースを試みる。失敗 → `status: failed` |
| gh CLI未認証 | エラーメッセージを出して即座に終了 |

いずれのエラーでも:
- `task-loop-state.json` にエラー状態を記録する
- `stopOnError` が `true` → ループ終了（終了サマリーへ）
- `stopOnError` が `false` → 次のタスクへ

## 終了サマリー

ループ終了時に以下のサマリーを出力する:

```
Task Loop 完了

処理結果:
  完了: {tasksCompleted} タスク
  失敗: {tasksFailed} タスク
  スキップ: {tasksSkipped} タスク
  残り: {remaining} タスク

PR一覧:
  - #{prNumber} {title} ({prUrl}) [完了]
  - #{prNumber} {title} ({prUrl}) [失敗]

{手動対応が必要なタスクがあれば}
手動対応が必要:
  - {ファイル名}: {理由}

終了理由: {全タスク完了 / maxTasks到達 / 時間制限超過 / エラー停止}
```
