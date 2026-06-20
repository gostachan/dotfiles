# Step 5: セキュリティチェック

## 5.1 SQL インジェクション（Snowflake）

- [ ] SQL クエリにパラメータバインド（`%s` または `?`）を使用しているか
- [ ] f-string や `.format()` で SQL を組み立てていないか

```python
# NG: SQL インジェクションの危険
cursor.execute(f"SELECT * FROM campaigns WHERE account_id = '{account_id}'")

# OK: パラメータバインド
cursor.execute("SELECT * FROM campaigns WHERE account_id = %s", (account_id,))
```

## 5.2 機密情報

- [ ] Snowflake 秘密鍵・接続情報がハードコードされていないか
- [ ] ADPOS API トークン・認証情報がコードにハードコードされていないか
- [ ] S3 バケット名・パスが定数または設定ファイルで管理されているか
- [ ] ログ出力に機密情報（接続文字列、秘密鍵、API トークン）が含まれていないか

## 5.3 パス・ファイル操作

- [ ] ユーザー入力を含むファイルパスで `../` 相対参照の検証がされているか（パストラバーサル）
- [ ] 一時ファイルに予測可能な名前を使っていないか（シンボリックリンク攻撃）

## セルフチェックポイント

- [ ] 指摘した脆弱性が実際のコードパスで到達可能
- [ ] Critical 判定する前に「攻撃者が入力を制御できるか」を確認済み
