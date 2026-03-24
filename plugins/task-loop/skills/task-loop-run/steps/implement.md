# implement モード: Steps 1〜4

選択したタスクに対して以下のステップを実行する。

## Step 1: タスク初期化

1. タスクファイルを全文読み込む
2. frontmatterから `title`、`commitPrefix` を取得する（titleがない場合はファイル名のハイフン区切り部分を使用）
3. ベースブランチが最新であることを確認する:
   ```bash
   git checkout {baseBranch}
   git pull origin {baseBranch}
   ```
4. タスク用ブランチを作成する:
   ```bash
   git checkout -b {branchPrefix}{ファイル名から拡張子を除いたもの}
   ```
   例: `task/001-add-auth`
5. タスクファイルのfrontmatterを `status: in_progress` に更新、`assignedAt` に現在時刻を設定
6. `task-loop-state.json` にタスクエントリを追加（status: "in_progress"、startedAt）
7. Task.md を更新: タスクエントリを **Todo** → **Processing** に移動
   - `Priority` フィールドを削除
   - `StartedAt`（現在時刻）、`Branch`（ブランチ名）、`Step: implementing` を追加
   - frontmatter の `updatedAt` を更新

## Step 2: 実装

1. タスクファイルの全セクションを読む（Description、Requirements、Files to Modify、Test Cases、Acceptance Criteria 等）
2. Task.md が読み込まれている場合:
   - Context の Tech Stack・Architecture・Constraints に従う
   - Shared Context を確認し、先行タスクとの整合性を維持する
   - Notes の規約・注意点に従ったコードを書く
3. タスクの内容に従って実装を行う
   - コードの読み取り、ファイルの作成・編集、必要に応じてコマンド実行
   - Test Cases が指定されている場合、テスト通過＝実装完了として扱う
4. タスクファイルに Test Command が指定されている場合:
   - テストを実行する
   - テストが失敗した場合は修正して再実行する
   - 3回修正してもテストが通らない場合はエラーとして扱う（エラーリカバリーへ）

## Step 3: コミット

1. 変更をステージングする:
   - `git add -A` は使用禁止。変更したファイルを個別に指定してステージングする
   - `git status` で変更ファイルを確認し、タスクに関連するファイルのみを `git add` する
   - `.env`、認証情報、ビルド成果物など不要なファイルがステージされていないことを確認する
   ```bash
   git add {変更したファイル1} {変更したファイル2} ...
   ```
2. コミットメッセージを作成する:
   - フォーマット: `{commitPrefix}: {変更内容の要約}`
   - commitPrefixはタスクファイルのfrontmatterから取得（デフォルト: `feat`）
   - タイトルをそのまま使うのではなく、実際の変更内容を簡潔に記述する
   - 変更が複数の論理的単位にまたがる場合は、コミットを分割することを検討する
   - 例:
     - `feat: JWTベースの認証ミドルウェアを追加`
     - `feat: ログイン・ログアウトAPIエンドポイントを実装`
3. コミットを実行する:
   ```bash
   git commit -m "{コミットメッセージ}"
   ```

## Step 4: PR作成

1. ブランチをプッシュする:
   ```bash
   git push -u origin {ブランチ名}
   ```
2. PR本文を生成する:
   - タスクの Description を要約
   - 変更内容の箇条書き
   - テスト方法（Test Command があれば記載）
   - フッター（設定の `prBodyFooter`）
3. PRを作成する:
   ```bash
   gh pr create --title "{commitPrefix}: {title}" --body "{PR本文}" --base {baseBranch}
   ```
4. レビュアーを設定する:
   ```bash
   gh pr edit {PR番号} --add-reviewer {reviewer}
   ```
5. PR番号とURLを記録する
6. タスクファイルのfrontmatterに `prUrl` を設定
7. `task-loop-state.json` を更新（prNumber、prUrl）
8. PR番号を `{tasksDir}/processing/.pr_number` に書き出す（外部ループがPR番号を参照するため）
