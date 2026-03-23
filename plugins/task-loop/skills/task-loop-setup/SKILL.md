---
name: task-loop-setup
description: task-loopの初期セットアップを行うスキル。タスクフォルダ・設定ファイル・タスクファイルの生成を対話的に行う。「タスクループのセットアップ」「task-loopの準備」「タスクを分割して自動実行の準備をしたい」といった場面で使用する。
---

# Task Loop Setup

task-loop-run スキルを使うための初期セットアップを行う。ユーザーとの対話を通じて、設定ファイル・タスクフォルダ・タスクファイルを生成する。

## セットアップフロー

以下のステップを順番に実行する。

### Step 1: 設定のヒアリング

ユーザーに以下の設定値を確認する。デフォルト値を提示し、変更が必要なものだけ聞く。

確認する項目:
- **baseBranch**: ベースブランチ名（デフォルト: `main`）
- **reviewer**: PRレビュアー（デフォルト: `copilot`）
- **mergeStrategy**: マージ方法（デフォルト: `squash`）
- **stopOnError**: エラー時に停止するか（デフォルト: `true`）
- **maxTasks**: 1回の実行で処理する最大タスク数（デフォルト: `0` = 無制限）

デフォルトのままでよい項目が多い場合は「デフォルト設定でよいですか？」と一括で確認してもよい。

### Step 2: task-loop-config.json の生成

ヒアリング結果をもとに、リポジトリルートに `task-loop-config.json` を生成する。
デフォルト値と異なるフィールドのみ記述する（全フィールドを書く必要はない）。

設定フォーマットの詳細は `references/loop-config-format.md` を参照。

例（デフォルトから変更があるもののみ）:
```json
{
  "baseBranch": "develop",
  "reviewer": "copilot",
  "maxTasks": 1
}
```

全てデフォルトの場合は、空のオブジェクト `{}` で生成する。

### Step 3: タスクディレクトリの作成

設定の `tasksDir`（デフォルト: `tasks`）ディレクトリを作成する。

### Step 4: .gitignore の更新

`.gitignore` に以下を追加する（既に存在する場合はスキップ）:

```
task-loop-state.json
```

`.gitignore` が存在しない場合は新規作成する。

### Step 5: タスクファイルの生成

ユーザーにタスクの入力方法を確認する:

**方法A: 直接入力**
ユーザーが実装したい内容を説明する。それを適切な粒度のタスクファイルに分割して生成する。

**方法B: 既存ドキュメントからの変換**
ユーザーが指定するドキュメント（計画書、設計書、issueリスト等）を読み込み、タスクファイルに分割して生成する。

**方法C: GitHub Issue からの変換**
`gh issue list` や `gh issue view` を使ってissueを読み込み、タスクファイルに変換する。

いずれの方法でも、タスクファイルフォーマット（`references/task-file-format.md`）に従って生成する。

### Step 6: タスクダッシュボードの生成

`task-loop-doc` スキルを実行し、カンバン形式のタスクダッシュボードを生成する。

このスキルが、タスクファイルとプロジェクト情報を分析して `Task.md` を自動生成する。

### Step 7: run-loop.sh の生成

リポジトリルートに `run-loop.sh` を生成する。このスクリプトは外部ループとして Claude CLI を繰り返し起動し、タスクを自動処理する。

生成する内容:
```bash
#!/bin/bash
set -euo pipefail

TASKS_DIR="${TASKS_DIR:-tasks}"

has_remaining_tasks() {
  for file in "$TASKS_DIR"/*.md; do
    [ -f "$file" ] || continue
    local status
    status=$(sed -n '/^---$/,/^---$/{ /^status:/{ s/^status:[[:space:]]*//; p; } }' "$file")
    if [ -z "$status" ] || [ "$status" = "pending" ] || [ "$status" = "in_progress" ]; then
      return 0
    fi
  done
  return 1
}

while true; do
  if ! has_remaining_tasks; then
    echo "全タスクが処理済みです"
    break
  fi

  claude -p "/task-loop-run を実行してください。maxTasks=1 で1タスクだけ処理してください。" --allowedTools "Bash(git:*),Bash(gh:*),Read,Write,Edit,Glob,Grep"
done
```

生成後に実行権限を付与する:
```bash
chmod +x run-loop.sh
```

### Step 8: セットアップ完了サマリー

生成したファイルの一覧と次のステップを出力する。

出力例:
```
セットアップが完了しました。

生成したファイル:
  - task-loop-config.json
  - Task.md
  - run-loop.sh
  - tasks/001-add-auth-module.md
  - tasks/002-setup-database-schema.md
  - tasks/003-implement-api-endpoints.md
  - .gitignore (更新)

次のステップ:
  1. 生成されたタスクファイルの内容を確認・修正してください
  2. タスクダッシュボード（Task.md）の内容を確認してください
  3. ./run-loop.sh を実行してタスクの自動実行を開始してください
```

## タスク分割ガイド

タスクを分割する際は以下のルールに従う:

- **1タスク = 1PR = 1つの独立した変更**にする
- タスクは単独でコミット・PRできる粒度にする
- 依存関係がある場合はファイル名の連番で順序を表現する
  - 例: `001-create-model.md` → `002-add-api-endpoint.md` → `003-add-frontend-page.md`
- タスクが大きすぎる場合は更に分割する（目安: 1タスクで変更するファイルが10個以下）
- テストとコードは同じタスクに含める（テストだけの別タスクにしない）
- 設定変更や依存追加は、それを使う実装タスクと同じタスクに含める
