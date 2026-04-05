# Task.md フォーマット

プロジェクトの技術的コンテキストを記述するファイル。`task-loop-doc` スキルが生成し、`task-loop-run` スキルがタスク実装時に参照する。

タスクの状態管理はフォルダ構造で行う（`todo/`、`processing/`、`done/`、`failed/`）。Task.md はコンテキスト情報のみを持つ。

## ファイル配置

- デフォルトファイル名: `Task.md`
- 配置場所: リポジトリルート（`task-loop-config.json` と同じ階層）
- `task-loop-config.json` の `planFile` フィールドで変更可能

## Frontmatter

```yaml
---
title: "プロジェクト名"
createdAt: "2026-03-22T10:00:00Z"
updatedAt: "2026-03-22T10:30:00Z"
totalTasks: 5
---
```

| フィールド | 型 | 必須 | 説明 |
|-----------|------|------|------|
| `title` | string | 必須 | プロジェクト名または機能名 |
| `createdAt` | string (ISO 8601) | 必須 | Task.md の生成日時 |
| `updatedAt` | string (ISO 8601) | 必須 | 最終更新日時 |
| `totalTasks` | number | 必須 | タスクファイルの総数 |

## 本文構造

Task.md は **Context セクション** のみで構成する。

---

### Context セクション

プロジェクトの技術的コンテキスト。AI がタスク実装時に参照する背景情報。

```markdown
## Context

### Tech Stack

- **言語**: TypeScript 5.x
- **ランタイム**: Node.js 20
- **フレームワーク**: Next.js 14 (App Router)
- **データベース**: PostgreSQL 16 + Prisma
- **テスト**: Vitest + Testing Library

### Architecture

src/
  app/           # Next.js App Router ページ
  components/    # UIコンポーネント
  lib/           # ビジネスロジック
  db/            # データベース関連

### Constraints

- 既存APIとの後方互換性を維持すること
- ESM only（CommonJSは使わない）

### Shared Context

- `001` で作成する Prisma クライアントは `src/lib/db.ts` から export する
- 認証トークンは JWT を使用

### Notes

- セキュリティ: 認証・認可の実装が正しいか
- パフォーマンス: N+1クエリが発生していないか
- ファイル名はkebab-case、コンポーネントはPascalCase
```

## 完全な Task.md の例

```markdown
---
title: "ECサイト認証機能"
createdAt: "2026-03-22T10:00:00Z"
updatedAt: "2026-03-22T11:00:00Z"
totalTasks: 5
---

## Context

### Tech Stack

- **言語**: TypeScript 5.x
- **フレームワーク**: Next.js 14 (App Router)
- **データベース**: PostgreSQL + Prisma
- **テスト**: Vitest

### Architecture

src/
  app/
    api/         # APIルート
    (auth)/      # 認証関連ページ
  lib/
    auth/        # 認証ロジック
    db/          # DB接続

### Constraints

- 既存のユーザーテーブルは変更しない（新しいauth_accountsテーブルを追加）
- bcryptでパスワードハッシュ化

### Shared Context

- `001` で作成する `auth_accounts` テーブルのスキーマを `002` 以降で使用する
- Prisma Client は `src/lib/db.ts` から import する

### Notes

- パスワードが平文で保存されていないか
- SQLインジェクション対策
- APIルートは `src/app/api/` 配下に配置
- エラーレスポンスは `{ error: string }` 形式
```
