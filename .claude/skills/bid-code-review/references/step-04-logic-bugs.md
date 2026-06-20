# Step 4: ロジックバグの検出

以下のパターンを重点的にチェックする。

## 4.1 条件分岐・データ処理

- [ ] 条件分岐の網羅性（if-else の漏れ、`match` 文の `case _` 有無）
- [ ] `None` チェック漏れ（Optional 型の値を直接使用していないか）
- [ ] 空リスト `[]` のチェック漏れ（`list[0]` アクセス前の length チェック）
- [ ] ゼロ除算の可能性（CPA 計算・予算計算等で分母が 0 になるケース）
- [ ] 辞書キーの存在チェック（`dict[key]` vs `dict.get(key)`）
- [ ] 日予算・tCPA の計算結果が負数や異常値にならないか

## 4.2 非同期・外部接続

- [ ] Snowflake クエリのエラーハンドリング（接続切れ、タイムアウト）
- [ ] S3 操作のエラーハンドリング（バケット不在、権限不足、ファイル不在）
- [ ] ADPOS（Meta/YDA/GDN）API 呼び出しのエラーハンドリング（レート制限、認証失敗、タイムアウト）
- [ ] EventBridge 通知の失敗時処理

## 4.3 データ変換

- [ ] 媒体（MediaType）ごとの分岐が新媒体追加時に漏れていないか
- [ ] 運用モード（CPA重視/予算重視）の条件分岐が全パターンを網羅しているか
- [ ] エンコーディング問題（文字列変換時の Unicode 正規化）

## 4.4 エラーハンドリングの網羅性

### 例外処理

- [ ] `raise` を使用する関数のうち、**呼び出し元でエラー回復が必要な箇所**で適切に `try/except` されているか
- [ ] アプリケーション境界（`src/main.py`）で未ハンドルの例外がプロセスをクラッシュさせないか
- [ ] `except Exception` のような広すぎるキャッチをしていないか（具体的な例外型を使用すべき）
- [ ] `except` ブロックで例外を握りつぶしていないか（`pass` のみの `except`）

### 早期リターンのビジネスインパクト

- [ ] `except` 内の `return` でスキップされる後続処理を列挙したか
- [ ] スキップされる処理にデータ整合性上の重要処理（API 更新、EventBridge 通知、ログ保存等）がないか
- [ ] 処理 A の失敗が処理 B のスキップを正当化するか（因果関係の確認）

```python
# NG: 予算更新失敗で EventBridge 通知もスキップされる
try:
    adpos.update_budget(campaign_id, new_budget)
except Exception:
    logger.error("予算更新に失敗")
    return  # ← 通知がスキップされる

eventbridge.notify(result)

# OK: 更新と通知を独立して処理
try:
    adpos.update_budget(campaign_id, new_budget)
except Exception:
    logger.error("予算更新に失敗")
    update_failed = True

eventbridge.notify(result, update_failed)
```

## セルフチェックポイント

- [ ] 各指摘箇所が実際の実行パスで到達可能であることを確認済み
- [ ] 「将来〜かもしれない」ではなく「現在の実装で発生しうる」問題のみ指摘している
