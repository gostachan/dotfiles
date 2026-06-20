# Step 7: テストパターンの網羅性

## 7.1 基本パターン

- [ ] **正常系**: 期待通りの入力での動作
- [ ] **異常系**: エラーケース、例外ケース
- [ ] **境界値**: 空リスト `[]`、`None`、0、負数、上限値（予算・tCPA の最大/最小値など）

## 7.2 テーブル駆動パターン準拠

- [ ] テストケースが `TypedDict` + `@pytest.mark.parametrize` 形式で定義されているか
- [ ] `TypedDict` のクラス名が `Test` で始まっていないか（pytest 誤認識の回避）
- [ ] テストケース名が日本語で「xxxの場合、yyyになる」形式か
- [ ] `input`（引数）と `expected`（期待値）が分離されているか

```python
# OK: テーブル駆動パターン
class BudgetCalcCase(TypedDict):
    name: str
    input: BudgetInput
    expected: DailyBudget

class TestDailyBudgetCalculator:
    TEST_CASES: ClassVar[list[BudgetCalcCase]] = [...]

    @pytest.mark.parametrize(
        ("input_params", "expected"),
        [(tc["input"], tc["expected"]) for tc in TEST_CASES],
        ids=[tc["name"] for tc in TEST_CASES],
    )
    def test_calculate(self, input_params: BudgetInput, expected: DailyBudget) -> None:
        ...
```

## 7.3 今回の変更に対するテスト

- [ ] 新規追加した関数・クラスのテストファイルが同じディレクトリに存在するか（`{name}_test.py`）
- [ ] 変更した既存ロジックのテストが更新されているか
- [ ] 削除した機能のテストも削除されているか

## 7.4 モックの適切性

- [ ] `domain/service/` のテストで外部依存（S3、Snowflake、ADPOS）をモックしているか
- [ ] `application/usecase/` のテストで `domain/repository/` の Protocol をモックしているか
- [ ] モックの戻り値が実際の Protocol 定義と型が一致しているか

## セルフチェックポイント

- [ ] 不足テストケースを列挙する際、具体的な入出力例を含めている
- [ ] テーブル駆動準拠の指摘は実装コード側の構造と比較した上で行っている
