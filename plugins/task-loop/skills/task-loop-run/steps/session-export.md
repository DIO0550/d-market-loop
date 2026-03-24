# セッションレポート書き出し

セッション終了前に、AIの動作内容をMarkdownファイルとして `session-logs/` ディレクトリに書き出す。

## 出力先

`{sessionLogsDir}/` ディレクトリ（デフォルト: `session-logs/`）に以下の命名規則で保存:

```
session-logs/{YYYY-MM-DD}_{HHmmss}_{mode}_{task-name}.md
```

例: `session-logs/2026-03-24_143052_implement_001-add-auth.md`

## レポートフォーマット

```markdown
---
sessionId: "{タイムスタンプ}"
mode: "{implement|review-check|error}"
task: "{タスクファイル名}"
startedAt: "{ISO-8601}"
endedAt: "{ISO-8601}"
result: "{success|failed|interrupted}"
---

# Session Report: {タスクタイトル}

## 概要
<!-- このセッションで何を行ったかの1-2行の要約 -->

## 実行ステップ

### 1. {ステップ名}
- **アクション**: {何をしたか}
- **結果**: {成功/失敗/スキップ}
- **詳細**: {必要に応じて補足}

### 2. {ステップ名}
...

## 変更したファイル
<!-- git diff --name-only の結果をリスト化 -->
- `path/to/file1.ts` — {変更内容の要約}
- `path/to/file2.ts` — {変更内容の要約}

## コミット
<!-- このセッションで作成したコミット -->
- `{commit-hash-short}` {コミットメッセージ}

## PR
<!-- PR を作成/更新した場合 -->
- PR #{number}: {title} ({url})

## レビュー対応
<!-- review-check モードの場合のみ -->
- **指摘数**: {n}件
- **対応内容**: {修正の要約}

## エラー・問題
<!-- 発生したエラーや問題点。なければ「なし」 -->

## 次のアクション
<!-- 後続セッションで必要な作業があれば記述 -->
```

## 生成手順

1. `session-logs/` ディレクトリが存在しなければ作成する
2. 現在のセッションで実行した内容を振り返り、上記フォーマットに沿ってレポートを生成する
3. `git diff --name-only` で変更ファイルを取得し、変更ファイルセクションに記載する
4. `git log --oneline` で今回のコミットを取得し記載する
5. レポートをファイルに書き出す

> **注意**: レポートはgit管理から除外される（`.gitignore` に `session-logs/` を追加済み）。ローカルの作業記録として蓄積される。
