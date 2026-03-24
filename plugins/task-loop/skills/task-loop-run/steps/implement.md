# 実装

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
   - 3回修正してもテストが通らない場合はエラーとして扱う（エラーリカバリーへ → `steps/error-recovery.md`）
