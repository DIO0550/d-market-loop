# Task.md フォーマット

カンバン形式のタスクダッシュボード兼計画書。`task-loop-doc` スキルが生成し、`task-loop-run` スキルがタスク処理時にセクション間でエントリを移動して進捗を反映する。

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

Task.md は **Context セクション** と **4つのカンバンセクション** で構成する。

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

---

### カンバンセクション

タスクを状態別に4つのセクションで管理する。

#### セクション間の遷移

```
Todo ──(タスク選択)──> Processing ──(マージ成功)──> Done
                            │
                            └──(エラー/失敗)──> Failed
```

#### タスクエントリの共通フィールド

全セクション共通:

| フィールド | 説明 |
|-----------|------|
| **ID**（太字） | タスクファイル名（`.md` 除く）。例: `001-setup-prisma` |
| **タイトル** | タスクの概要（ID の後にハイフン区切りで記述） |
| Blockers | `none` または依存先タスクIDのカンマ区切り |
| File | 個別タスクファイルへのパス |

#### セクション別の追加フィールド

| フィールド | Todo | Processing | Done | Failed |
|-----------|------|------------|------|--------|
| Priority | o | - | - | - |
| StartedAt | - | o | - | - |
| Branch | - | o | - | - |
| Step | - | o | - | - |
| CompletedAt | - | - | o | - |
| PR | - | - | o | o（あれば） |
| FailedAt | - | - | - | o |
| Reason | - | - | - | o |

**Step の値**: `implementing` → `reviewing` → `fixing` → `merging`

---

### Todo セクション

未処理のタスク。`task-loop-doc` が生成時に全タスクをここに配置する。

```markdown
## Todo

- [ ] **001-setup-prisma** - Prismaスキーマ初期設定
  - Blockers: none
  - File: `tasks/001-setup-prisma.md`
  - Priority: high

- [ ] **002-add-user-model** - ユーザーモデル追加
  - Blockers: `001-setup-prisma`
  - File: `tasks/002-add-user-model.md`
  - Priority: normal
```

### Processing セクション

処理中のタスク。`task-loop-run` が Todo から移動する。

```markdown
## Processing

- [ ] **003-auth-api** - 認証APIエンドポイント
  - Blockers: `002-add-user-model`
  - File: `tasks/003-auth-api.md`
  - StartedAt: 2026-03-22T10:15:00Z
  - Branch: `task/003-auth-api`
  - Step: reviewing
```

### Done セクション

完了したタスク。`task-loop-run` が Processing から移動する。完了順に追記。

```markdown
## Done

- [x] **001-setup-prisma** - Prismaスキーマ初期設定
  - Blockers: none
  - File: `tasks/001-setup-prisma.md`
  - CompletedAt: 2026-03-22T10:15:00Z
  - PR: https://github.com/owner/repo/pull/42
```

### Failed セクション

失敗したタスク。`task-loop-run` が Processing から移動する。

```markdown
## Failed

- **004-auth-frontend** - ログインページ実装
  - Blockers: `003-auth-api`
  - File: `tasks/004-auth-frontend.md`
  - FailedAt: 2026-03-22T10:45:00Z
  - Reason: テストが3回修正後も失敗
  - PR: https://github.com/owner/repo/pull/44
```

---

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

## Todo

- [ ] **004-auth-frontend** - ログインページ実装
  - Blockers: `003-auth-api`
  - File: `tasks/004-auth-frontend.md`
  - Priority: normal

- [ ] **005-add-e2e-tests** - E2Eテスト追加
  - Blockers: `004-auth-frontend`
  - File: `tasks/005-add-e2e-tests.md`
  - Priority: low

## Processing

- [ ] **003-auth-api** - 認証APIエンドポイント
  - Blockers: `002-add-user-model`
  - File: `tasks/003-auth-api.md`
  - StartedAt: 2026-03-22T10:30:00Z
  - Branch: `task/003-auth-api`
  - Step: implementing

## Done

- [x] **001-add-auth-schema** - 認証スキーマ追加
  - Blockers: none
  - File: `tasks/001-add-auth-schema.md`
  - CompletedAt: 2026-03-22T10:15:00Z
  - PR: https://github.com/owner/repo/pull/42

- [x] **002-add-user-model** - ユーザーモデル追加
  - Blockers: `001-add-auth-schema`
  - File: `tasks/002-add-user-model.md`
  - CompletedAt: 2026-03-22T10:30:00Z
  - PR: https://github.com/owner/repo/pull/43

## Failed

（なし）
```

## task-loop-run からの参照方法

### 読み込み

タスク処理開始時に Task.md を読み込み、以下の情報を活用する:

1. **Context** — Tech Stack・Architecture・Constraints・Shared Context・Notes を実装時に遵守する
2. **カンバンセクション** — 現在のタスク状態を把握する

### 更新タイミング

| タイミング | 操作 |
|-----------|------|
| タスク開始（Step 1） | Todo → Processing に移動。StartedAt, Branch, Step を追加 |
| 実装中（Step 2） | Step を `implementing` に設定（移動時に設定済み） |
| レビュー待ち（Step 5） | Step を `reviewing` に更新 |
| レビュー修正（Step 6） | Step を `fixing` に更新 |
| マージ中（Step 7） | Step を `merging` に更新 |
| タスク完了（Step 8） | Processing → Done に移動。CompletedAt, PR を追加。チェックボックスを `[x]` に |
| タスク失敗 | Processing → Failed に移動。FailedAt, Reason を追加。チェックボックスを除去 |

各更新時に frontmatter の `updatedAt` も更新する。

### Task.md が存在しない場合

Task.md が存在しない場合は、全ての更新をスキップする（後方互換性を維持）。タスクファイルの内容のみに基づいて実装する。
