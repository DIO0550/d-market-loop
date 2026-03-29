# allowedCommands

`task-loop-config.json` の `allowedCommands` フィールドで、Claudeセッションで実行を許可するBashコマンドを指定する。

## 仕組み

許可は2層で適用される:

1. **PreToolUse hook** — 対話セッションでコマンドを自動許可
2. **run-loop.sh (`--allowedTools`)** — `claude -p` 非対話セッションでコマンドを許可

また、許可コマンド一覧は `run-loop.sh` 実行時にプロンプトへ自動注入され、Claudeがどのコマンドを使えるかを認識できる。

## デフォルト許可コマンド

以下はテンプレートに組み込み済みで、設定不要:

**git:**
`git status`, `git add`, `git commit`, `git push`, `git pull`, `git fetch`, `git checkout`, `git switch`, `git branch`, `git diff`, `git log`, `git stash`, `git merge`, `git rebase`

**gh:**
`gh pr create`, `gh pr view`, `gh pr merge`, `gh pr list`, `gh api`, `gh auth status`

**TypeScript / JavaScript（チェック系）:**
`tsc --noEmit`, `tsc -p`, `eslint`, `prettier --check`, `vitest`, `jest`

## プロジェクト固有の許可コマンド

デフォルトに含まれないコマンドは `allowedCommands` で追加する。

```json
{
  "allowedCommands": [
    "pnpm test",
    "pnpm run lint",
    "pnpm run build"
  ]
}
```

## マッチング

各コマンドは前方一致で評価される。ただしコマンドチェーン（`&&`, `||`, `;`, `|`）やサブシェル（`` ` ``, `$()`）を含むコマンドは拒否される。

- `"git commit"` → `git commit -m "msg"` にマッチ
- `"pnpm test"` → `pnpm test` にマッチ、`pnpm run build` にはマッチしない
- `"pnpm test && rm -rf /"` → コマンドチェーンとして拒否

## デフォルト禁止コマンド

以下のコマンドは危険性が高いため、デフォルトで禁止リストに含まれる。コマンド文字列のどこかに含まれていれば拒否される:

| コマンド | 理由 |
|---------|------|
| `npx` | 任意のパッケージをダウンロード・実行できる |
| `pnpm dlx` | npx と同様 |
| `pnpm install` | postinstall スクリプトで任意コードが実行される |
| `npm install` | 同上 |
| `yarn add` | 同上 |
| `pip install` | 同上 |

禁止リストは許可リストより先に評価され、常に優先される。
