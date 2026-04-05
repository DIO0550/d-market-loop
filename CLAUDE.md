# CLAUDE.md

## プロジェクト概要

d-market-loop は Claude Code プラグインで、タスクベースの開発ワークフローを自動化する。タスクファイルを順番に処理し、実装 → コミット → PR作成 → レビュー → 修正 → マージ のサイクルを自律的にループ実行する。

### 構成

- `plugins/task-loop/` — メインプラグイン
  - `skills/task-loop-setup/` — 初期セットアップスキル（設定ファイル・タスクフォルダ・実行スクリプトの配置）
  - `skills/task-loop-run/` — タスク実行スキル（implement / review-check / error の3モード）
  - `skills/task-loop-doc/` — タスクファイル・計画書（Task.md）の生成スキル
  - `hooks/` — PostCompact・セッション終了時のフック

### 動作の仕組み

外部シェルスクリプト (`run-loop.sh`) が Claude のセッションをモード別に起動し、レビュー待ちのポーリングはシェル側が担当する。タスクの状態は `tasks/` ディレクトリ間のファイル移動（todo → processing → done/failed）とタスクファイルのfrontmatterで管理する。

## コミットルール

### ステージング
- `git add -A` や `git add .` は使用禁止
- 変更したファイルを個別に `git add` すること
- `git status` で差分を確認してから、関連ファイルのみをステージングする
- `.env`、認証情報、ビルド成果物、一時ファイルをコミットしない

### コミットメッセージ
- Conventional Commits 形式を使用する: `{prefix}: {変更内容の要約}`
- prefix: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`
- メッセージは実際の変更内容を具体的に記述する（タスクタイトルのコピーではなく）
- 変更が複数の論理的単位にまたがる場合はコミットを分割する

### 良い例
```
feat: JWTベースの認証ミドルウェアを追加
fix: レビュー完了検知でreviewRequestsの状態を正しく判定
refactor: PostCompact hookをプラグインレベルに移動
```

### 悪い例
```
feat: 認証モジュールを追加する        # タスクタイトルそのまま、具体性に欠ける
fix: address review comments          # 何を修正したか不明
fix: レビュー指摘対応                  # 同上
```
