# allowedCommands

`task-loop-config.json` の `allowedCommands` フィールドで、Claudeセッションで実行を許可するBashコマンドを指定する。

## 仕組み

許可は2層で適用される:

1. **PreToolUse hook** — 対話セッションでコマンドを自動許可
2. **run-loop.sh (`--allowedTools`)** — `claude -p` 非対話セッションでコマンドを許可

また、許可コマンド一覧は `run-loop.sh` 実行時にプロンプトへ自動注入され、Claudeがどのコマンドを使えるかを認識できる。

## マッチング

各コマンドは前方一致で評価される。

- `"git commit"` → `git commit -m "msg"` にマッチ
- `"pnpm test"` → `pnpm test` にマッチ、`pnpm run build` にはマッチしない

## 設定例

git/gh を含め、必要なコマンドを全て列挙する。

```json
{
  "allowedCommands": [
    "git status",
    "git add",
    "git commit",
    "git push",
    "git checkout",
    "git switch",
    "git branch",
    "git diff",
    "git log",
    "gh pr create",
    "gh pr view",
    "gh pr merge",
    "gh api",
    "pnpm test",
    "pnpm run lint",
    "pnpm run build"
  ]
}
```
