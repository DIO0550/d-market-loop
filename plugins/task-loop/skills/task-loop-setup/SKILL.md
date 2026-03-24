---
name: task-loop-setup
description: task-loopの初期セットアップを行うスキル。設定ファイル・タスクフォルダ・ループスクリプトの配置を行う。「タスクループのセットアップ」「task-loopの準備」といった場面で使用する。
---

# Task Loop Setup

task-loop-run スキルを使うための初期セットアップを行う。ユーザーとの対話を通じて、設定ファイル・タスクフォルダ・実行スクリプトを配置する。

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

設定の `tasksDir`（デフォルト: `tasks`）配下に以下のサブフォルダを作成する:

```
tasks/
├── todo/        # 未処理のタスクファイル
├── processing/  # 処理中のタスクファイル
├── done/        # 完了したタスクファイル
└── failed/      # 失敗したタスクファイル
```

また、セッションログ出力用のディレクトリも作成する:

```
session-logs/    # セッションごとのAI動作ログ（Markdown）
```

### Step 4: .gitignore の更新

`.gitignore` に以下を追加する（既に存在する場合はスキップ）:

```
# task-loop
tasks/
Task.md
task-loop-state.json
.pr_number
session-logs/
```

タスクファイル（`tasks/` と `Task.md`）は実行時の状態管理ファイルであり、実装の成果物ではないためgit管理から除外する。これにより、PRにタスク管理の差分が混入することを防ぎ、複数ブランチでのコンフリクトも回避できる。

`.gitignore` が存在しない場合は新規作成する。

### Step 5: ループスクリプトと指示書の配置

`assets/` から以下の2ファイルをリポジトリルートにコピーする。

1. **run-loop.sh** — 外部ループスクリプト
2. **task-loop-instructions.md** — Claude CLIに渡す指示書

```bash
cp assets/run-loop.sh ./run-loop.sh
cp assets/task-loop-instructions.md ./task-loop-instructions.md
chmod +x run-loop.sh
```

※ `assets/` のパスは、このスキルの `assets/` ディレクトリを指す。Readツールで読み取り、Writeツールでリポジトリルートに書き出すこと。

`run-loop.sh` は外部ループとして Claude CLI を繰り返し起動し、タスクを自動処理する。起動時に同じディレクトリの `task-loop-instructions.md` を読み込んでプロンプトとして渡す。残タスク（pending / in_progress）がなくなると自動で終了する。

### Step 6: セットアップ完了サマリー

生成したファイルの一覧と次のステップを出力する。

出力例:
```
セットアップが完了しました。

生成したファイル:
  - task-loop-config.json
  - run-loop.sh
  - task-loop-instructions.md
  - tasks/ (todo/, processing/, done/, failed/)
  - .gitignore (更新)

次のステップ:
  1. task-loop-doc スキルでタスクファイルとダッシュボードを生成してください
  2. 生成されたタスクファイルの内容を確認・修正してください
  3. ./run-loop.sh を実行してタスクの自動実行を開始してください
```
