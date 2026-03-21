# タスクファイルフォーマット

## 命名規則

タスクファイルは `tasks/` ディレクトリに配置する Markdown ファイル。

- ファイル名: `NNN-descriptive-name.md`（NNNは3桁の連番）
- 連番が実行順序を決定する
- 例: `001-add-auth.md`, `002-setup-database.md`, `010-fix-styling.md`

## Frontmatter

```yaml
---
title: "認証モジュールを追加する"    # 必須: タスクタイトル（PRタイトルにも使用）
status: pending                       # 任意: pending | in_progress | completed | failed | skipped
priority: normal                      # 任意: low | normal | high
commitPrefix: feat                    # 任意: conventional commit のプレフィックス（デフォルト: feat）
assignedAt: ""                        # 自動設定: タスク開始時に記録
completedAt: ""                       # 自動設定: タスク完了時に記録
prUrl: ""                             # 自動設定: PR作成時に記録
---
```

### status の扱い

| 値 | 意味 |
|----|------|
| （未設定） | `pending` と同等。未処理タスク |
| `pending` | 未処理 |
| `in_progress` | 処理中（中断復帰の検出に使用） |
| `completed` | 完了済み。スキップされる |
| `failed` | 失敗。スキップされる |
| `skipped` | 手動でスキップ指定。スキップされる |

## 本文構造

```markdown
## Description

何を実装するかの説明。自由記述。

## Requirements

- 具体的な要件1
- 具体的な要件2

## Files to Modify

変更対象のファイルやディレクトリのヒント（任意）。

- `src/auth/` - 認証関連のモジュール
- `tests/auth.test.ts` - テストファイル

## Test Command

実装後に実行するテストコマンド（任意）。指定がある場合、テストが通るまで実装を続ける。

```bash
npm test
```

## Acceptance Criteria

完了条件のチェックリスト（任意）。

- [ ] ログイン機能が動作する
- [ ] テストが全て通る

## Notes

追加のコンテキスト、リンク、参考情報（任意）。
```

## 最小限のタスクファイル例

```markdown
---
title: "READMEにプロジェクト概要を追加"
---

## Description

README.mdにプロジェクトの概要、セットアップ手順、使い方を追加する。
```
