---
name: bid-code-review
description: bid_allocation_agent パッケージに最適化されたコードレビュー。DDD・クリーンアーキテクチャ・Python・バッチシステムの観点で品質・安全性・保守性を検証する。作業完了前に必ず実行すること。
model: claude-opus-4-7
---

# Code Review（bid_allocation_agent 専用）

品質・安全性・保守性の観点から、変更カテゴリに応じた必要最小限のステップのみを実行するコードレビュースキル。詳細な検証手順は `references/` に分離している。

---

## 1. 最優先ルール（ハードガードレール）

| # | ルール | 違反時の影響 |
|---|--------|-------------|
| 1 | **指摘する前に、該当ファイルの現在状態を Read で確認する**。diff だけで指摘しない | 誤指摘によるレビュー信頼性の低下 |
| 2 | **指摘で言及するファイルパス・モジュールは実在を Glob で確認する** | 存在しないパスへの言及でレビューが無効化 |
| 3 | **Critical 判定は「現在のコードで確実に発生する問題」のみに限定**する。推測・将来可能性は最大 Minor | 重大度インフレで真の Critical が埋もれる |
| 4 | **モノレポ横断影響分析（Step 6.3）は全変更で必須**。他パッケージへの影響を網羅的に検証する | 他パッケージの破壊的変更見落とし |
| 5 | **Step 8 の自己再検証は内部作業として必ず実施**し、過程はユーザーに出力しない | 推測に基づく不正確な指摘が最終出力に残る |

---

## 2. 入力パラメータ・モード判定

| `$ARGUMENTS` | モード | 差分コマンド |
|-------------|--------|-------------|
| PR 番号（例: `123`） | PR モード | `gh pr diff 123` |
| ブランチ名（例: `feat/xxx`） | ブランチモード | `git diff main...feat/xxx` |
| ファイルパス（例: `src/domain/...`） | ファイルモード | `git diff main...HEAD -- <パス>` |
| 省略時 | 現在ブランチモード | `git diff main...HEAD` |

**オプションフラグ**:
- `--with-codex`: Step 9（Codex 補完レビュー）を有効化する（デフォルト無効）。例: `/bid-code-review 123 --with-codex`
- PR モード時のみ Step 10（GitHub インラインコメント投稿）が起動する。投稿前にユーザー承認が必須で、自動投稿はしない

**必須**: 差分取得後、**変更された各ファイルを `Read` で全文読み込み**してから次 STEP へ進む。diff 差分だけでは前後の文脈が不足する。

---

## 3. 使用ツール一覧

| 用途 | 推奨ツール | 禁止ツール・操作 |
|------|-----------|-----------------|
| 差分取得 | `Bash(gh pr diff)` / `Bash(git diff)` | 目視・推測 |
| ファイル全文確認 | `Read(path)`（**複数ファイルは並行 Read**） | diff のみで指摘する |
| 使用箇所検索 | `Grep(pattern, path, glob)` | `Grep` 結果のみで確定（Read で文脈確認） |
| パス実在確認 | `Glob(pattern)` | 指摘文に記載後の確認 |
| 外部依存バージョン確認 | `Bash(gh api repos/...)` / `Bash(uv pip show)` | トレーニング知識に基づく断定 |
| PR インラインコメント投稿 | `Bash(gh api repos/{owner}/{repo}/pulls/{n}/reviews)` | Web UI での手動投稿 |

---

## 4. 変更カテゴリ別の実行ステップ表

変更ファイルをカテゴリに分類し、必要なステップのみを実行する。**Step 6.3 と Step 8 は全カテゴリで必須。Step 9（Codex 補完レビュー）は `--with-codex` 指定時のみ実行（デフォルト無効）。Step 10（GitHub インラインコメント）は PR モード時のみ起動し、投稿前にユーザー承認が必須で、自動投稿はしない。**

| カテゴリ | 対象パターン | 実行ステップ |
|---------|------------|------------|
| Python ソースコード | `src/**/*.py`（テスト以外） | Step 2 → 3 → 4 → 5 → 6 → 7 → 8 |
| テストコード | `src/**/*_test.py` | Step 3 → 7 → 8 |
| CI/CD ワークフロー | `.github/workflows/**` | Step 6.1 → 6.2 → 6.3 → 8 |
| GitHub 設定 | `.github/**`（workflows 以外） | Step 6.2 → 6.3 → 8 |
| 設定ファイル | `pyproject.toml`, `Dockerfile` 等 | Step 6.3 → 8 |
| ドキュメント | `docs/**` | Step 6.3 → 8 |
| Claude Code 設定 | `.claude/**`, `CLAUDE.md` | Markdown 構文の確認 → Step 6.3 → 8 |

**混在変更の扱い**: `src/` と `docs/` の両方が変更されている場合、**ファイルごと**に該当ステップを実行。

**後処理（モード別）**:
- **PR モード**: 全カテゴリのステップ完了後、Step 10（GitHub インラインコメント投稿）を起動。投稿前にユーザー承認が必須で、自動投稿はしない
- **`--with-codex` 指定時**: Step 8 の後、Step 9（Codex 補完レビュー）を実行してから Step 10 へ進む

---

## 5. ワークフロー

### Step 1: 対象の特定と差分取得

- **実行内容**: 以下を**1バッチで並行発行**し、全て完了してから次 Step に進む
  1. 差分取得（入力モード判定表に従ったコマンド）
  2. 全リファレンスファイルの先読み（`references/` 配下の全 .md を一括 Read）
- **差分取得完了後**: 変更ファイル一覧を確認し、各ファイルを **並行 Read**（同一バッチ）で全文読み込み
- **並行発行する Read の一覧**（差分取得と同バッチ）:
  - `references/step-02-architecture.md`
  - `references/step-04-logic-bugs.md`
  - `references/step-05-security.md`
  - `references/step-06-monorepo-impact.md`
  - `references/step-07-test-patterns.md`
  - `references/step-08-self-verification.md`
  - `references/output-format.md`
  - `references/verification-rules.md`
  - `--with-codex` 指定時のみ追加: `references/step-09-codex-cross-check.md`
  - PR モード時のみ追加: `references/step-10-github-inline-comment.md`
- **セルフチェック**:
  - [ ] 差分取得コマンドと全リファレンス Read を同一バッチで発行した
  - [ ] 変更ファイル一覧が全て Read 済み
  - [ ] 各ファイルのカテゴリを変更カテゴリ別実行ステップ表で判定済み

### Step 2: クリーンアーキテクチャ整合性

- **詳細**: Step 1 で先読み済みの `references/step-02-architecture.md` を参照（再 Read 不要）
- **目的**: 依存方向違反 / ファイル配置 / インターフェース整合性 / simulation モジュール同期を検証

### Step 3: Python コーディングルール準拠

#### 型ヒント
- [ ] 全関数・メソッドに引数・戻り値の型ヒントあり
- [ ] `Any` 型を正当理由なく使用していない
- [ ] プリミティブ型露出箇所で値オブジェクトを使うべきでないか

#### コメント・docstring 禁止
- [ ] 「What」の説明コメントが追加されていない
- [ ] docstring が追加されていない（例外: コードから読み取れない「Why」のみ）
- [ ] コメントがコードから読み取れない「Why」のみになっている

#### 命名規則
| 対象 | ルール |
|------|--------|
| クラス名 | `PascalCase` |
| 変数・引数・関数 | `snake_case` |
| 定数 | `UPPER_SNAKE_CASE` |
| プライベート | 先頭 `_` |

### Step 4: ロジックバグの検出

- **詳細**: Step 1 で先読み済みの `references/step-04-logic-bugs.md` を参照（再 Read 不要）
- **目的**: 条件分岐・外部接続・予算/tCPA 計算のバグパターンを検出

### Step 5: セキュリティチェック

- **詳細**: Step 1 で先読み済みの `references/step-05-security.md` を参照（再 Read 不要）
- **目的**: SQL インジェクション・機密情報漏洩・パストラバーサルを検出

### Step 6: 影響範囲の分析

- **詳細**: Step 1 で先読み済みの `references/step-06-monorepo-impact.md` を参照（再 Read 不要）
- **目的**: Python 呼び出し元検索（6.0）/ CI/CD ワークフロー `paths` フィルタ（6.1）/ GitHub 設定影響（6.2）/ 他パッケージ影響（6.3・**必須**）/ simulation モジュール影響（6.4）を検証

### Step 7: テストパターンの網羅性

- **詳細**: Step 1 で先読み済みの `references/step-07-test-patterns.md` を参照（再 Read 不要）
- **目的**: 正常系/異常系/境界値・テーブル駆動準拠・モック適切性を検証

### Step 8: 自己再検証（内部作業）

- **詳細**: Step 1 で先読み済みの `references/step-08-self-verification.md` を参照（再 Read 不要）
- **内容**: 実行パス検証 / 重大度再分類 / パス実在確認 / 重複・矛盾排除
- **重要**: 再検証過程はユーザーに**出力しない**

### Step 9: Codex 補完レビュー（クロスチェック）

- **デフォルト無効**（`--with-codex` 指定時のみ実行）
- **詳細**: Step 1 で先読み済みの `references/step-09-codex-cross-check.md` を参照（再 Read 不要。`--with-codex` 未指定時は先読みも不要）
- **目的**: Step 8 までに整理した Claude のレビュー結果ドラフトを Codex CLI に渡し、見落とし・反対意見・補強観点を取得する
- **実行条件**: `$ARGUMENTS` に `--with-codex` が含まれている場合のみ実行する。**指定がない場合は完全スキップ**し、出力セクションに `⏭ スキップ（理由: --with-codex 未指定）` と記載する
- **前提条件（`--with-codex` 指定時）**: codex CLI が `command -v codex` で検出できる場合のみ実行。不在時はスキップしてメインフロー継続
- **メタ循環回避**: `.claude/**` 配下のファイルを Codex に渡す変更ファイル一覧・差分本文から除外して Step 9 を実行する（このスキル定義自身を Codex に渡すと評価が循環するため）。除外後に変更ファイルが 0 件になる場合のみ Step 9 をスキップする
- **失敗時の挙動**: タイムアウト・実行エラー・空応答のいずれもメインフローを止めず、最終出力に「スキップ理由」を記載

### Step 10: GitHub PR インラインコメント投稿

- **PR モード専用**（`$ARGUMENTS` が PR 番号の場合のみ起動）
- **詳細**: Step 1 で先読み済みの `references/step-10-github-inline-comment.md` を参照（再 Read 不要。PR モード以外は先読みも不要）
- **実行条件**: `$ARGUMENTS` が PR 番号の場合のみ起動する。ブランチモード・ファイルモード・現在ブランチモードは skip
- **目的**: Step 1〜9 で収集した指摘を GitHub PR の Files Changed タブにインラインコメントとして投稿し、レビュアーが diff 上で直接確認できるようにする
- **承認必須**: `gh api` 投稿前に投稿プレビューを提示し、`AskUserQuestion` でユーザー承認を取得する。**自動投稿は禁止**
- **失敗時の挙動**: 指摘 0 件 / ユーザー非承認 / `gh api` 失敗のいずれもメインフローを止めず、最終出力にスキップ理由を記載

---

## 6. 出力フォーマット

- **詳細**: Step 1 で先読み済みの `references/output-format.md` を参照（再 Read 不要）
- **セクション省略ルール**:
  - 0 件の重大度セクションは省略
  - 実行しなかったステップに対応するセクションは省略
  - **例外 1**: Step 9（Codex 補完レビュー）はスキップ時も「Codex 補完レビュー」セクションを出力し、実行ステータス行に `⏭ スキップ（理由: --with-codex 未指定 / codex CLI 未インストール / ...）` を明記する
  - **例外 2**: Step 10（GitHub インラインコメント）は PR モード時のみ出力。投稿件数（またはユーザーが投稿を承認しなかった場合は「ユーザー承認が得られなかったため投稿スキップ」、指摘 0 件時は「指摘 0 件のため投稿なし」）を総評の末尾に記載する

---

## 7. 検証ルール（全体に適用）

以下は全 STEP 共通のルール。詳細は `references/verification-rules.md`。

- **パス・ファイル参照の検証**: 指摘に記載するパスは `Glob` で実在確認してから記述
- **外部依存の最新情報確認**: GitHub Actions バージョンは `gh api` で確認、断定禁止
- **外部ツール設定の仕様検証**: 設定キーの動作を推測で断定せず、公式ドキュメント確認

---

## 8. 禁止事項

| 禁止行為 | 理由 | 正しい対応 |
|---------|------|-----------|
| diff だけで指摘する | 前後文脈不足で誤指摘 | 各ファイルを Read で全文確認 |
| 推測で Critical 判定 | 真の Critical が埋もれる | 到達可能性を確認し、推測は最大 Minor |
| パス実在未確認で指摘 | レビュー全体の信頼性喪失 | `Glob` で実在確認 |
| トレーニング知識でバージョン断定 | 古い情報で誤った指摘 | `gh api` で最新確認、不明なら Suggestion |
| モノレポ他パッケージ影響を省略 | 他チームへの想定外影響 | Step 6.3 を全変更で実行 |
| simulation モジュール影響確認を省略 | tools/simulation/ の整合性が壊れる | Step 6.4 を domain/application/di.py 変更時に実行 |
| 自己再検証過程を出力する | ユーザー混乱・冗長 | 内部作業として実施し、最終結果のみ出力 |
| Codex の指摘を採否判定なしで最終出力に反映 | Codex の誤指摘がレビュー品質を毀損 | 「Codex 指摘の最終判定」テーブルで採否を Claude が明示 |
| `--with-codex` 未指定なのに Step 9 を実行する | 不要な外部 CLI 呼び出しで処理時間が増大 | `$ARGUMENTS` を確認し、指定がなければ完全スキップ |
| codex CLI 不在・失敗で Step 1〜8 を中断 | メインレビューが提供されない | Step 9 はオプショナル扱い、スキップ理由を記載してフロー継続 |
| `.claude/**` をフィルタせず Codex に渡す | レビュー対象とレビューロジックがメタ循環 | `.claude/**` 配下を除外した変更ファイル一覧・差分本文を Codex に渡す |
| PR モードでないのに Step 10 を実行する | 存在しない PR 番号への投稿試行でエラー | `$ARGUMENTS` が PR 番号かどうかを確認してから実行 |
| ユーザー承認なしにインラインコメントを投稿する | 誤指摘・余計な指摘の自動投稿で PR の見通しが悪化 | プレビューを提示し `AskUserQuestion` で承認を取得してから投稿 |
| `gh api` 失敗でレビュー全体を中断する | テキストレビュー結果が失われる | `gh api` 失敗はエラー報告のみ、テキスト出力は継続 |

---

## 9. 利用例

```
# 現在ブランチの差分をレビュー
/bid-code-review

# 特定 PR をレビュー（Files Changed にインラインコメントも投稿）
/bid-code-review 123

# 特定ファイルのみレビュー
/bid-code-review src/domain/service/daily_budget_calculator.py

# Codex 補完レビューも有効にしてレビュー（処理時間増・オプション）
/bid-code-review 123 --with-codex
```

---

## 10. リソース

### references/

- [step-02-architecture.md](references/step-02-architecture.md) — クリーンアーキテクチャ整合性の詳細
- [step-04-logic-bugs.md](references/step-04-logic-bugs.md) — ロジックバグ検出パターン + エラーハンドリング
- [step-05-security.md](references/step-05-security.md) — セキュリティチェック詳細
- [step-06-monorepo-impact.md](references/step-06-monorepo-impact.md) — 影響範囲・モノレポ横断分析・simulation モジュール影響
- [step-07-test-patterns.md](references/step-07-test-patterns.md) — テーブル駆動テストパターン
- [step-08-self-verification.md](references/step-08-self-verification.md) — Step 8 自己再検証の手順（実行パス検証 / 重大度再分類 / パス実在確認 / 重複・矛盾排除）
- [step-09-codex-cross-check.md](references/step-09-codex-cross-check.md) — Codex 補完レビューの実行手順・プロンプト・失敗時挙動（`--with-codex` 時のみ）
- [step-10-github-inline-comment.md](references/step-10-github-inline-comment.md) — GitHub PR インラインコメント投稿の実行手順・プレビュー・承認フロー・失敗時挙動（PR モード時のみ）
- [output-format.md](references/output-format.md) — 出力フォーマット詳細テンプレート
- [verification-rules.md](references/verification-rules.md) — 全 STEP 共通の検証ルール（パス実在確認 / 外部依存最新情報確認 / 外部ツール設定の仕様検証）

### 関連スキル

- `/bid-create-commit` — レビュー通過後にコミット作成
- `/bid-create-pr` — レビュー通過後に PR 作成

### 関連ドキュメント

- `docs/architecture.md` — クリーンアーキテクチャ定義
- `docs/coding_guidelines.md` — Python コーディング規約
- `CLAUDE.md` — simulation モジュール同期ルール
