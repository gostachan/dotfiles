---
name: bid-create-commit
description: bid_allocation_agent パッケージの変更を Conventional Commits 準拠でコミットするガイド
model: claude-opus-4-7
---

# コミット作成ガイド

ステージング対象の確認・CI チェック・コミットメッセージ生成をまとめて実施し、Conventional Commits 準拠のコミットを作成するスキル。Auto mode でも CI スキップが発生しないよう、AI 自身が CI を実行し exit code を STEP 進行条件として扱う。

---

## 1. 最優先ルール（ハードガードレール）

| # | ルール | 違反時の影響 |
|---|--------|-------------|
| 1 | **`main` ブランチ上での実行は禁止** | main ブランチを直接汚染する事故 |
| 2 | **認証情報・シークレットをコミットに含めない**。`.env`・トークン・パスワード・API キーが diff に含まれれば即中断 | 認証情報の公開 |
| 3 | **CI（ruff format / ruff check / pyright / pytest）を AI 自身が Bash で実行し、全て exit=0 でなければコミットしない** | CI 失敗コミットが積み重なり、後の PR で失敗する |
| 4 | **コミットメッセージは Conventional Commits 準拠**（`/^(feat\|fix\|docs\|refactor\|chore\|test\|ci)(\(.*\))?[!]?:\s.+/` にマッチ） | リリースノート・autolabeler に分類されない |
| 5 | **ユーザー承認なしで `git commit` を実行しない** | 意図しない内容がコミットされる |

---

## 2. 入力パラメータ

| `$ARGUMENTS` の内容 | 動作 |
|-------------------|------|
| なし | 変更内容から AI がコミットメッセージを生成 |
| コミットメッセージのヒント（例: `予算計算ロジックを改善`） | ヒントを元にコミットメッセージを生成 |
| ファイルパス（例: `src/domain/entities/campaign.py`） | 指定ファイルのみステージング、メッセージは AI が生成 |

---

## 3. 使用ツール一覧

| 用途 | 推奨ツール | 禁止ツール・操作 |
|------|-----------|-----------------|
| ブランチ確認 | `Bash(git branch --show-current)` | - |
| 変更内容確認 | `Bash(git status --porcelain)` / `Bash(git diff)` / `Bash(git diff --cached)` | 目視判定 |
| CI 実行 | `Bash(uv run ruff format --check .)` 等 | ユーザーに実行依頼のみ（Auto mode で skip 危険） |
| ファイルのステージング | `Bash(git add {files})` | `git add -A` / `git add .`（意図しないファイルを含む恐れ） |
| コミット実行 | `Bash(git commit -m "...")` | `git commit --no-verify` |

---

## 4. ワークフロー

### STEP 1: ブランチ確認・必要に応じて作成

- **目的**: main への直接コミットを防ぐ。`main` 上の場合は **その場で命名規約に沿った作業ブランチを作成**し、main → 作業ブランチ → コミットを一気通貫で進められるようにする。
- **ブランチ命名規約**: `<prefix>/OMAI-XXXX-<内容>`（例: `feat/OMAI-1493-meta-off-cv-id-fix`）
  - `<prefix>`: 変更の性質を表すラベル。コミットメッセージで使う Conventional Commits のタイプ（`feat` / `fix` / `refactor` / `docs` / `chore` など）に合わせる
  - `OMAI-XXXX`: 対応する Jira チケット番号。**必ず含める**ことで PR / コミット / Jira チケットの三者がトラッキング可能になる
  - `<内容>`: **英小文字とハイフン**を使った短い説明
  - 詳細はチームの[ブランチ運用ルール](https://ai-opetech.atlassian.net/wiki/spaces/omai/pages/269680958#%E3%83%96%E3%83%A9%E3%83%B3%E3%83%81%E9%81%8B%E7%94%A8)を参照
- **実行内容**:
  ```bash
  git branch --show-current
  ```
- **IF/ELSE**:
  - `main` → 以下のフロー:
    1. `AskUserQuestion` で次の 3 項目を確認する（既に把握できる情報があれば変更差分から推定して初期値として提示）:
       - プレフィックス（`feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `ci` など、Conventional Commits のタイプ）
       - Jira チケット番号（数字のみ・例: `1493`）。番号なしの場合は中断し、ユーザーに作成を促す（PR / コミット / Jira の三者トラッキング維持のため必須）
       - 内容スラッグ（**英小文字＋ハイフンのみ**・例: `meta-off-cv-id-fix`）
    2. ブランチ名を `<prefix>/OMAI-XXXX-<内容>` 形式で組み立て、以下の正規表現で検証する:
       ```bash
       BRANCH="{組み立てたブランチ名}"
       if echo "$BRANCH" | grep -Eq '^(feat|fix|refactor|docs|chore|test|ci)/OMAI-[0-9]+-[a-z]+(-[a-z]+)*$'; then
         echo "VALID"
       else
         echo "INVALID"
       fi
       ```
    3. `VALID` の場合、ユーザーに「このブランチ名で作成して進めますか？」と確認し、承認後に作成:
       ```bash
       git fetch origin main
       git checkout -b "$BRANCH" origin/main
       ```
    4. `INVALID` または承認が得られない → 中断してユーザーに手動でのブランチ作成を案内する
  - それ以外 → 次 STEP
- **セルフチェックポイント**:
  - [ ] 現在ブランチが `main` 以外
  - [ ] `main` から作成した場合、命名規約 `<prefix>/OMAI-XXXX-<内容>` に準拠していることを正規表現で検証済み
  - [ ] 内容スラッグが英小文字とハイフンのみで構成されていることを確認した
  - [ ] ユーザーがブランチ名を明示承認した

### STEP 2: 変更内容の確認

- **目的**: 何をコミットするか全体像を把握する。
- **実行内容**:
  ```bash
  git status --porcelain
  git diff --stat
  git diff --cached --stat
  ```
- **IF/ELSE**:
  - staged・unstaged ともに変更なし → **エラー中断**（コミットする変更がない）
  - 変更あり → 内容を解析して次 STEP
- **セルフチェックポイント**:
  - [ ] コミットすべき変更が存在することを確認した

### STEP 3: ステージング対象の決定

- **目的**: コミットに含めるファイルを確定し、認証情報の混入を防ぐ。
- **実行内容**:
  1. `git diff` / `git diff --cached` でファイルごとの差分を確認
  2. 以下のファイルが含まれていないか確認する:
     - `.env` / `.env.*`
     - `*secret*` / `*credential*` / `*token*` / `*password*` / `*api_key*`
     - パターン: `(SECRET|TOKEN|PASSWORD|API_KEY|PRIVATE_KEY)\s*=\s*\S+` が diff に現れていないか
- **IF/ELSE**:
  - 認証情報パターン検出 → **即中断**。ユーザーに報告し `.gitignore` 追加・`git reset` を案内する
  - `$ARGUMENTS` にファイルパス指定あり → 指定ファイルのみステージング
  - `$ARGUMENTS` なし → 変更ファイル一覧をユーザーに提示し、ステージング対象を確認する
    ```
    ## ステージング候補

    {git status --porcelain の出力}

    全ファイルをコミットしますか？ または特定ファイルを指定してください。
    ```
- **セルフチェックポイント**:
  - [ ] 認証情報パターンが diff に含まれていないことを確認した
  - [ ] ステージング対象ファイルをユーザーが承認済み（または `$ARGUMENTS` で指定済み）

### STEP 4: CI の自動実行【AI 自身が実行する】

- **目的**: コミット前に CI チェックを全て通過させ、壊れたコミットの積み重ねを防ぐ。
- **実行内容**:
  ```bash
  REPO_ROOT=$(git rev-parse --show-toplevel)
  cd "${REPO_ROOT}/packages/bid_allocation_agent"

  uv run ruff format --check .
  uv run ruff check .
  uv run pyright
  uv run pytest
  ```
- **IF/ELSE**:
  - 全コマンド exit=0 → 次 STEP
  - `ruff format --check` 失敗 → `uv run ruff format .` で自動修正してから再実行
  - `ruff check` 失敗 → `uv run ruff check --fix .` で自動修正を試みる。修正できない場合は Edit で手動修正
  - `pyright` / `pytest` 失敗 → Read/Edit/Bash でエラーを修正 → 再実行 → exit=0 まで繰り返す
- **セルフチェックポイント（全て必須）**:
  - [ ] `ruff format --check` exit=0
  - [ ] `ruff check` exit=0
  - [ ] `pyright` exit=0
  - [ ] `pytest` exit=0
- **AI 実装ノート**:
  - **ユーザーに「コマンド貼り付けを依頼」はしない**。Bash で直接実行すること
  - `ruff format` で自動修正したファイルは、ステージング対象に追加する必要がある（STEP 3 のステージングに含める）

### STEP 5: コミットメッセージの生成

- **目的**: Conventional Commits 準拠のメッセージをドラフトする。
- **メッセージ形式**:
  ```
  {type}(bid_allocation_agent): {概要}
  ```
  - `{type}`: `feat` / `fix` / `docs` / `refactor` / `chore` / `test` / `ci`
  - `{概要}`: 変更の「何を」ではなく「なぜ・何のために」を簡潔に（日本語可）
- **type の選び方**:

  | type | 使うとき |
  |------|---------|
  | `feat` | 新機能・新しいビジネスロジックの追加 |
  | `fix` | バグ修正 |
  | `docs` | ドキュメント変更のみ（`docs/` / `*.md`） |
  | `refactor` | 動作を変えないリファクタリング |
  | `chore` | ビルド設定・依存関係・ツール変更 |
  | `test` | テストコードの追加・修正のみ |
  | `ci` | CI/CD 設定の変更のみ |

- **複数 Issue 対応時**: タイトルに `(OMAI-XXXX)` を付記する（例: `feat(bid_allocation_agent): 予算計算ロジックを改善 (OMAI-1234)`）
- **提示フォーマット**:
  ```
  ## コミット提案

  ### ステージング対象
  {git add するファイル一覧}

  ### コミットメッセージ
  {type}(bid_allocation_agent): {概要}
  ```

### STEP 5.5: メッセージ検証

- **目的**: メッセージが Conventional Commits 形式に準拠していることを構文的に保証する。
- **実行内容**:
  ```bash
  MSG="{commit_message}"
  if echo "$MSG" | grep -Eq '^(feat|fix|docs|refactor|chore|test|ci)(\(.*\))?[!]?:\s.+'; then
    echo "VALID"
  else
    echo "INVALID"
  fi
  ```
- **IF/ELSE**:
  - `VALID` → 次 STEP
  - `INVALID` → STEP 5 に戻りメッセージ再生成
- **セルフチェックポイント**:
  - [ ] 正規表現マッチを確認済み

### STEP 6: ユーザー承認【USER_APPROVAL_REQUIRED】

- **IF/ELSE**:
  - 「OK」/ 承認 → STEP 7
  - メッセージ修正指示 → STEP 5 に戻る
  - ステージング変更指示 → STEP 3 に戻る
- **セルフチェックポイント**:
  - [ ] ユーザーが「OK」と明示した

### STEP 7: コミット実行

- **実行内容**:
  ```bash
  git add {staged_files}

  git commit -m "$(cat <<'EOF'
  {commit_message}

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
  EOF
  )"
  ```
- **セルフチェックポイント**:
  - [ ] `git commit` が exit=0 で完了した
  - [ ] `git log --oneline -1` でコミットが正しく記録されていることを確認した
  - [ ] ユーザーにコミットハッシュとメッセージを返却済み

---

## 5. AI 実装ノート（全体）

- **`git add -A` / `git add .` は使わない**: 意図しないファイル（`*.pyc`, `.env`, キャッシュ等）が混入する。必ず個別ファイル指定。
- **STEP 4 は skip 厳禁**: Auto mode では「コマンドを提示してユーザーの貼り付けを待つ」パターンは無音で skip されるため、必ず Bash で直接実行する。
- **`ruff format` 自動修正後は再ステージングが必要**: 修正されたファイルが unstaged になるため、`git add` に含める。
- **`--no-verify` は絶対に使わない**: hook が存在しなくても習慣として使わない。
- **simulation モジュールへの影響確認**: `src/` 配下のドメインモデル・リポジトリ Protocol・`AllocateUseCase`・`di.py` を変更した場合、`tools/simulation/` への影響も確認してからコミットする（CLAUDE.md 参照）。

---

## 6. 禁止事項

| 禁止行為 | 理由 | 正しい対応 |
|---------|------|-----------|
| `main` へ直接コミット | main ブランチ保護・レビュー回避 | STEP 1 で命名規約に沿った作業ブランチをその場で作成（ユーザー承認必須） |
| `git add -A` / `git add .` | 意図しないファイルの混入 | ファイルを個別指定 |
| 認証情報を含むコミット | 情報漏洩 | STEP 3 で検出・中断し `.gitignore` 追加を案内 |
| CI 失敗のままコミット | 壊れたコミット履歴・後の PR で CI 失敗 | STEP 4 で exit=0 を担保してからコミット |
| 非 Conventional Commits メッセージ | リリースノート欠落・履歴が読みにくい | STEP 5.5 で正規表現マッチ検証 |
| `git commit --no-verify` | hook バイパス | 必ず CI パスさせる |
| `--amend` による既存コミット改ざん | push 済み・共有コミットの破壊 | 新規コミットを追加する |

---

## 7. 利用例

```
# 変更内容から自動でコミットメッセージを生成
/bid-create-commit

# ヒントを与えてメッセージを生成
/bid-create-commit 予算計算ロジックを改善

# 特定ファイルのみコミット
/bid-create-commit src/domain/entities/campaign.py
```

---

## 8. リソース

### 関連スキル

- `/bid-create-pr` — コミット済み変更を PR として公開
- `/bid-code-review` — コミット前のセルフレビュー

### 関連ファイル

- `packages/bid_allocation_agent/CLAUDE.md` — コーディング規約・simulation モジュール同期ルール
- `packages/bid_allocation_agent/docs/coding_guidelines.md` — 詳細コーディングガイドライン
