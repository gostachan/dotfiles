# Step 6: 影響範囲の分析

対象: Python コード / CI/CD ワークフロー / モノレポ横断影響 / simulation モジュール影響

## 6.0 Python コードの影響分析

`src/` 配下のファイルが変更された場合に実行する。

1. **呼び出し元の検索**:
   ```
   Grep("変更した関数名|クラス名", path: "src/")
   ```

2. **Protocol 変更の影響**: `domain/repository/` を変更した場合、全実装クラスを検索
   ```
   Grep("implements対象の Protocol 名", path: "src/infrastructure/")
   Grep("implements対象の Protocol 名", path: "tools/simulation/")
   ```

3. **モデル変更の影響**: `domain/model/` 変更時、使用箇所を全て確認

4. **DI コンテナの確認**: 新クラス/Protocol が `src/di.py` に正しく登録されているか

## 6.1 CI/CD ワークフローのモノレポスコープ検証

`.github/workflows/` 変更時は**必ず実行**。

**背景**: モノレポのため、`paths` フィルタがないと無関係なパッケージ変更でトリガー。

### 検証項目

| チェック項目 | 検出方法 | 重大度 |
|-------------|---------|--------|
| `paths` / `paths-ignore` フィルタの有無 | `on.push` / `on.pull_request` に `paths` キーがあるか | フィルタなし → **Major** |
| フィルタが対象パッケージに限定されているか | `paths` の値が `packages/bid_allocation_agent/**` を含むか | スコープ過大 → **Major** |
| 既存ワークフローとの整合性 | `Glob(".github/workflows/bid-allocation-agent-*.yml")` で比較 | 不一致 → **Minor** |
| `workflow_dispatch` / `schedule` の妥当性 | パッケージ固有の定期実行が他に影響しないか | 影響あり → **Major** |

### 判定例

```yaml
# NG: paths フィルタなし
on:
  push:
    branches: [main]

# OK: 対象パッケージに限定
on:
  push:
    branches: [main]
    paths:
      - 'packages/bid_allocation_agent/**'
```

### 例外

- `workflow_dispatch` のみ（手動実行専用）
- リポジトリ全体適用ワークフロー（auto-assign, labeler 等）

## 6.2 GitHub 設定ファイルの影響検証

`.github/` 配下（labeler.yml, release-drafter*.yml 等）が変更された場合:

- [ ] 設定を参照するワークフローを特定し、影響範囲を確認
- [ ] モノレポ内の他パッケージ用設定との干渉がないか確認
- [ ] 設定変更がワークフローのトリガー条件やフィルタに影響しないか確認

## 6.3 モノレポ他パッケージ影響の網羅的検証【必須】

**全ての変更**（`src/`, `.github/`, 設定ファイル問わず）に対して実行。結果は出力フォーマットの「モノレポ横断影響分析」に**必ず記載**。

### 検証対象

```
packages/
├── bid_allocation_agent/   # 本パッケージ
├── cr_agent/               # クリエイティブエージェント
└── sns_structure_agent/    # SNS 構造エージェント
```

### 6.3.1 影響スコープ判定

| ファイルのパス | 影響スコープ | 検証アクション |
|--------------|------------|--------------|
| `packages/bid_allocation_agent/**` | bid_allocation_agent のみ | 影響なし（確認不要） |
| `.github/workflows/bid-allocation-agent-*` | bid_allocation_agent のみ | `paths` フィルタ確認（Step 6.1） |
| `.github/workflows/update-release-drafts.yml` | `paths` フィルタ次第 | フィルタスコープ確認 |
| `.github/workflows/*` (上記以外) | 全パッケージの可能性 | Step 6.3.2 実行 |
| `.github/*.yml` (workflows 以外) | 参照元ワークフロー次第 | Step 6.3.3 実行 |
| ルート設定 (`pyproject.toml` 等) | 全パッケージの可能性 | Step 6.3.3 実行 |

### 6.3.2 ワークフロー変更の他パッケージ影響

各パッケージ（sns_structure_agent, cr_agent）ごとに:

1. トリガー条件が対象パッケージ変更で発火するか（`paths` / `paths-ignore`）
2. ワークフロー内で対象パッケージファイルを参照・変更しているか（`working-directory`, `run` コマンドのパス）
3. 共有リソース（secrets, environments, artifacts）の競合がないか

### 6.3.3 設定ファイル変更の他パッケージ影響

1. 設定ファイル参照元ワークフローを `Grep` で特定
   ```
   Grep("{設定ファイル名}", path: ".github/workflows/")
   ```
2. 特定したワークフローが他パッケージに影響するか確認
3. 設定値の変更が他パッケージの動作を変えないか確認

### 出力ルール

- **全パッケージについて検証結果を明記**（影響なしの場合も根拠を記載）
- 検証をスキップしたパッケージがあってはならない

## 6.4 simulation モジュールへの影響確認【domain/application/di.py 変更時】

CLAUDE.md に定義された以下の変更が含まれる場合、`tools/simulation/` への影響を必ず確認する。

| 変更内容 | 確認コマンド |
|---------|------------|
| `domain/repository/` Protocol のシグネチャ変更 | `find tools/simulation/ -name "*.py" \| xargs grep -l "該当Protocol名"` |
| `domain/model/` フィールド追加・変更 | `find tools/simulation/ -name "*.py" \| xargs grep -l "該当モデル名"` |
| `AllocateUseCase` のコンストラクタ・`execute()` 引数変更 | `grep -r "AllocateUseCase" tools/simulation/` |
| `BidManagementUnitFactory` / 戦略クラスの変更 | `grep -r "BidManagementUnit\|Factory" tools/simulation/` |
| `src/di.py` の変更 | `find tools/simulation/ -name "di.py"` で対応ファイルを確認 |
| 新しい MediaType の追加 | `grep -r "MediaType" tools/simulation/` |

影響が見つかった場合は **Major** として指摘し、simulation モジュール側の修正も必要なことをレポートに記載する。

## セルフチェックポイント

- [ ] Grep で呼び出し元検索を実施済み
- [ ] `.github/` 変更時は `paths` フィルタ確認済み
- [ ] 他パッケージ 2 つ（sns_structure_agent, cr_agent）について明示的に判定済み
- [ ] domain/application/di.py 変更時は `tools/simulation/` への影響確認済み
