# Step 2: クリーンアーキテクチャ整合性

変更された各ファイルについて、DDD + オニオン/クリーンアーキテクチャの原則違反を検証する。

## 2.1 依存方向の違反チェック

```
正しい依存方向:
Infrastructure → Application → Domain
```

| 違反パターン | 検出方法 |
|-------------|---------|
| `domain/` が `infrastructure/` を import | `Grep("from.*infrastructure\|import.*infrastructure", path: "src/domain/", glob: "*.py")` |
| `domain/` が `application/` を import | `Grep("from.*application\|import.*application", path: "src/domain/", glob: "*.py")` |
| `application/` が `infrastructure/` を import | `Grep("from.*infrastructure\|import.*infrastructure", path: "src/application/", glob: "*.py")` |

Grep 結果は `Read` で文脈確認してから違反として確定させる。

## 2.2 ファイル配置の妥当性

| 配置すべき層 | 判定基準 |
|-------------|---------|
| `domain/model/` | ビジネスデータ構造（`@dataclass(frozen=True)` / 値オブジェクト） |
| `domain/model/campaign_setting/` | 媒体別（GDN/YDA/Meta）CampaignSetting モデル |
| `domain/repository/` | リポジトリの Protocol 定義（抽象インターフェース） |
| `domain/service/` | エンティティ単体で表現できない判定・変換ロジック |
| `application/usecase/` | 複数サービス・リポジトリを組み合わせる処理フロー |
| `application/query/` | 読み取り専用のクエリサービス |
| `application/service/` | アプリケーション層のサービス |
| `infrastructure/snowflake/` | Snowflake リポジトリの具象実装 |
| `infrastructure/s3/` | S3 リポジトリの具象実装 |
| `infrastructure/adpos/` | ADPOS（Meta/YDA/GDN）API クライアントの具象実装 |
| `infrastructure/eventbridge/` | EventBridge 通知の具象実装 |
| `config/` | 設定値・環境変数の読み込み |
| `src/di.py` | DI コンテナ（具象クラスの組み立て・注入） |

## 2.3 インターフェースと実装の整合性

- [ ] `domain/repository/` に新しい Protocol メソッドを追加した場合、全ての具象実装（`infrastructure/` + simulation の mock）で実装されているか
- [ ] `infrastructure/` に新しい具象クラスを追加した場合、対応する `domain/repository/` の Protocol が存在するか
- [ ] 新しいインターフェース/実装が `src/di.py` に登録されているか

## 2.4 simulation モジュールとの同期

以下を変更した場合、`tools/simulation/` への影響を確認する（CLAUDE.md 参照）:

| 変更対象 | 確認すべき simulation 側のファイル |
|---------|----------------------------------|
| `domain/repository/` の Protocol シグネチャ | simulation 内の mock リポジトリ実装 |
| `domain/model/` のフィールド追加・変更 | simulation 内でそのモデルを生成している箇所 |
| `application/usecase/AllocateUseCase` のコンストラクタ・`execute()` 引数 | `tools/simulation/` の UseCase 呼び出し箇所 |
| `src/di.py` | `tools/simulation/di.py` 相当ファイル |
| 新しい MediaType の追加 | simulation 内の媒体別分岐ロジック |

確認コマンド:
```bash
find tools/simulation/ -name "*.py" | xargs grep -l "変更したクラス名|関数名"
```

## セルフチェックポイント

- [ ] Grep 結果を Read で文脈確認し、false positive を除外済み
- [ ] 新規ファイルがディレクトリ配置表のいずれかに該当することを確認済み
- [ ] Protocol 追加・変更時は全実装クラス（simulation mock 含む）の更新を確認済み
- [ ] simulation モジュールへの影響確認が必要な変更の場合、`tools/simulation/` を確認済み
