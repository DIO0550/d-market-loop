# allowedCommands

`task-loop-config.json` の `allowedCommands` フィールドで、プロジェクト固有の許可コマンドを追加指定する。

## 仕組み

許可は2層で適用される:

1. **PreToolUse hook** — 対話セッションでコマンドを自動許可
2. **run-loop.sh (`--allowedTools`)** — `claude -p` 非対話セッションでコマンドを許可

また、許可コマンド一覧は `run-loop.sh` 実行時にプロンプトへ自動注入され、Claudeがどのコマンドを使えるかを認識できる。

## デフォルト許可コマンド

テンプレートに組み込み済みで、設定不要:

**git:** `status`, `add`, `commit`, `push`, `pull`, `fetch`, `checkout`, `switch`, `branch`, `diff`, `log`, `stash`, `merge`, `rebase`

**gh:** `pr create`, `pr view`, `pr merge`, `pr list`, `api`, `auth status`

**ファイルシステム（読み取り系）:** `ls`, `cat`, `wc`, `which`, `command -v`

**ファイルシステム（書き込み系）:** `mkdir -p`, `cp`, `mv`

**TypeScript / JavaScript:** `tsc --noEmit`, `tsc -p`, `eslint`, `prettier --check`, `vitest`, `jest`

**pnpm:** `test`, `run lint`, `run build`, `run typecheck`, `run format`

## デフォルト禁止コマンド

テンプレートに組み込み済みで、設定不要。許可リストと同様に前方一致で評価される:

| コマンド | 理由 |
|---------|------|
| `npx` | 任意のパッケージをダウンロード・実行できる |
| `pnpm dlx` | npx と同様 |
| `pnpm install` | postinstall スクリプトで任意コードが実行される |
| `pnpm add` | 依存関係の変更 |
| `pnpm remove` | 依存関係の変更 |
| `npm install` | postinstall スクリプトで任意コードが実行される |
| `npm ci` | 同上 |
| `yarn add` | 依存関係の変更 |
| `yarn install` | postinstall スクリプトで任意コードが実行される |
| `pip install` | 任意パッケージのインストール |
| `rm` | ファイル削除 |
| `rmdir` | ディレクトリ削除 |

禁止リストは許可リストより先に評価され、常に優先される。

## プロジェクト固有の追加

デフォルトに含まれないコマンドは `allowedCommands` で追加する。

```json
{
  "allowedCommands": [
    "pnpm run dev",
    "pnpm run e2e"
  ]
}
```

## マッチング

各コマンドは前方一致で評価される。ただしコマンドチェーン（`&&`, `||`, `;`, `|`）やサブシェル（`` ` ``, `$()`）を含むコマンドは拒否される。

- `"git commit"` → `git commit -m "msg"` にマッチ
- `"pnpm test"` → `pnpm test` にマッチ、`pnpm run build` にはマッチしない
- `"pnpm test && rm -rf /"` → コマンドチェーンとして拒否
