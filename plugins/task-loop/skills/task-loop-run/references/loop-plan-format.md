# ループ全体計画書フォーマット

ループ全体の実行計画を記述するドキュメント。`task-loop-setup` スキルが生成し、`task-loop-run` スキルがループ開始時に読み込んで各タスクの実装に活用する。

## ファイル配置

- デフォルトファイル名: `task-loop-plan.md`
- 配置場所: リポジトリルート（`task-loop-config.json` と同じ階層）
- `task-loop-config.json` の `planFile` フィールドで変更可能

## Frontmatter

```yaml
---
title: "プロジェクト名 - ループ実行計画"
createdAt: "2026-03-22T10:00:00Z"
totalTasks: 5
estimatedDuration: "2h"
---
```

| フィールド | 型 | 必須 | 説明 |
|-----------|------|------|------|
| `title` | string | 必須 | 計画のタイトル |
| `createdAt` | string (ISO 8601) | 必須 | 計画書の生成日時 |
| `totalTasks` | number | 必須 | タスクファイルの総数 |
| `estimatedDuration` | string | 任意 | 全タスクの推定所要時間 |

## 本文構造

計画書は以下の3セクションで構成する。

### Section 1: Project Context

プロジェクトの概要と技術的なコンテキスト。AI がタスク実装時に参照する背景情報。

```markdown
## Project Context

### Overview

プロジェクトの概要を1-3段落で記述する。何を作っているか、目的は何か。

### Tech Stack

- **言語**: TypeScript 5.x
- **ランタイム**: Node.js 20
- **フレームワーク**: Next.js 14 (App Router)
- **データベース**: PostgreSQL 16 + Prisma
- **テスト**: Vitest + Testing Library
- **その他**: Docker, GitHub Actions

### Architecture

プロジェクトのアーキテクチャ概要。ディレクトリ構成、レイヤー構成、主要なパターンなど。

src/
  app/           # Next.js App Router ページ
  components/    # UIコンポーネント
  lib/           # ビジネスロジック
  db/            # データベース関連

### Constraints

- 既存APIとの後方互換性を維持すること
- Node.js 20以上が必須
- ESM only（CommonJSは使わない）
```

### Section 2: Task Overview

タスク一覧と実行順序、依存関係を俯瞰する。

```markdown
## Task Overview

### Execution Order

| # | ファイル | タイトル | 依存先 | 推定時間 |
|---|---------|---------|--------|---------|
| 1 | 001-setup-prisma.md | Prismaスキーマ初期設定 | なし | 15min |
| 2 | 002-add-user-model.md | ユーザーモデル追加 | #1 | 20min |
| 3 | 003-auth-api.md | 認証APIエンドポイント | #2 | 30min |
| 4 | 004-auth-frontend.md | ログインページ実装 | #3 | 25min |
| 5 | 005-add-e2e-tests.md | E2Eテスト追加 | #4 | 20min |

### Dependency Graph

001-setup-prisma
  └→ 002-add-user-model
       └→ 003-auth-api
            └→ 004-auth-frontend
                 └→ 005-add-e2e-tests

### Shared Context

タスク横断で共有すべきコンテキスト。あるタスクの実装が後続タスクに影響する情報。

- `001` で作成する Prisma クライアントのインスタンスは `src/lib/db.ts` から export する。以降のタスクはここから import する
- 認証トークンは JWT を使用。`003` で実装するが、`004` 以降でも同じトークン形式を前提とする
```

### Section 3: Risks & Notes

リスク、注意事項、判断基準を記述する。

```markdown
## Risks & Notes

### Known Risks

- **データベースマイグレーション**: Prismaのマイグレーションが失敗した場合、以降の全タスクに影響する。`001` のタスクでマイグレーションが成功することを必ず確認する
- **外部API依存**: `003` で外部認証プロバイダーのAPIを利用する。モックが必要な場合がある

### Coding Conventions

プロジェクト固有のコーディング規約やルール。

- ファイル名はkebab-caseを使用
- コンポーネントはPascalCase
- テストファイルは `*.test.ts` で同じディレクトリに配置
- import順序: 外部 → 内部 → 相対パス

### Review Focus Points

レビュー時に特に注目すべきポイント。

- セキュリティ: 認証・認可の実装が正しいか
- パフォーマンス: N+1クエリが発生していないか
- テストカバレッジ: 主要なパスがテストされているか
```

## 完全な計画書の例

```markdown
---
title: "ECサイト認証機能 - ループ実行計画"
createdAt: "2026-03-22T10:00:00Z"
totalTasks: 3
estimatedDuration: "1h"
---

## Project Context

### Overview

既存のECサイトに認証機能を追加するプロジェクト。メール+パスワードによるログイン機能を実装する。

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

## Task Overview

### Execution Order

| # | ファイル | タイトル | 依存先 | 推定時間 |
|---|---------|---------|--------|---------|
| 1 | 001-add-auth-schema.md | 認証スキーマ追加 | なし | 15min |
| 2 | 002-auth-api.md | 認証API実装 | #1 | 25min |
| 3 | 003-login-page.md | ログインページ | #2 | 20min |

### Dependency Graph

001-add-auth-schema
  └→ 002-auth-api
       └→ 003-login-page

### Shared Context

- `001` で作成する `auth_accounts` テーブルのスキーマを `002` 以降で使用する
- Prisma Client は `src/lib/db.ts` から import する

## Risks & Notes

### Known Risks

- Prismaマイグレーションの失敗で後続タスクが全てブロックされる

### Coding Conventions

- APIルートは `src/app/api/` 配下に配置
- エラーレスポンスは `{ error: string }` 形式

### Review Focus Points

- パスワードが平文で保存されていないか
- SQLインジェクション対策
```

## task-loop-run からの参照方法

ループ開始時に計画書を読み込み、以下の情報を活用する:

1. **Project Context** — 各タスクの実装時に技術スタック・アーキテクチャ・制約条件を考慮する
2. **Shared Context** — タスク間の連携情報を参照し、一貫した実装を行う
3. **Coding Conventions** — コーディング規約に従った実装をする
4. **Dependency Graph** — 現在のタスクが依存する先行タスクの完了を前提とする
5. **Known Risks** — リスクを意識し、影響範囲が大きいタスクでは特に慎重に実装する
6. **Review Focus Points** — レビューで指摘されやすいポイントを事前に意識する

計画書ファイルが存在しない場合は、スキップして通常通りタスクを処理する（後方互換性を維持）。
