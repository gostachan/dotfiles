---
name: bid-create-commit
description: bid_allocation_agent パッケージの変更を Conventional Commits 準拠でコミットするガイド
model: claude-opus-4-7
---

# コミット作成ガイド

ステージング対象の確認・CI チェック・コミット分割計画・コミットメッセージ生成をまとめて実施し、Conventional Commits 準拠のコミットを作成するスキル。Auto mode でも CI スキップが発生しないよう、AI 自身が CI を実行し exit code を STEP 進行条件として扱う。変更が大きい場合は **意味が成立する最小単位（目安: 平均 200 行程度 / コミット）** に分割し、レビューしやすいコミット履歴を作る。

---

## 1. 最優先ルール（ハードガードレール）

| # | ルール | 違反時の影響 |
|---|--------|-------------|
| 1 | **`main` ブランチ上での実行は禁止** | main ブランチを直接汚染する事故 |
| 2 | **認証情報・シークレットをコミットに含めない**。`.env`・トークン・パスワード・API キーが diff に含まれれば即中断 | 認証情報の公開 |
| 3 | **CI（ruff format / ruff check / pyright / pytest）を AI 自身が Bash で実行し、全て exit=0 でなければコミットしない** | CI 失敗コミットが積み重なり、後の PR で失敗する |
| 4 | **コミットメッセージは Conventional Commits 準拠**（`/^(feat\|fix\|docs\|refactor\|chore\|test\|ci)(\(.*\))?[!]?:\s.+/` にマッチ） | リリースノート・autolabeler に分類されない |
| 5 | **ユーザー承認なしで `git commit` を実行しない** | 意図しない内容がコミットされる |
| 6 | **コミットは「意味が成立する最小単位」に分割する**。1 コミットが大きくなる場合は、独立してレビュー可能な論理単位へ分割する（**目安: 平均 200 行程度 / コミット**） | レビュー負荷増・revert/二分探索の粒度が粗くなる |

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
| ファイル内の一部分のみステージング | `Bash(git apply --cached {patch})`（`git diff {file}` から該当 hunk のみ抽出したパッチを適用） | `git add -p`（インタラクティブのため Auto mode で停止） |
| ステージング解除 | `Bash(git restore --staged {files})` | - |
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

### STEP 3: コミット対象スコープの確定・認証情報スキャン

- **目的**: 今回コミットする変更の全体集合（スコープ）を確定し、認証情報の混入を防ぐ。実際のファイル分割は STEP 5 の分割計画で行う。
- **実行内容**:
  1. `git diff` / `git diff --cached` でファイルごとの差分を確認
  2. 以下のファイルが含まれていないか確認する:
     - `.env` / `.env.*`
     - `*secret*` / `*credential*` / `*token*` / `*password*` / `*api_key*`
     - パターン: `(SECRET|TOKEN|PASSWORD|API_KEY|PRIVATE_KEY)\s*=\s*\S+` が diff に現れていないか
- **IF/ELSE**:
  - 認証情報パターン検出 → **即中断**。ユーザーに報告し `.gitignore` 追加・`git reset` を案内する
  - `$ARGUMENTS` にファイルパス指定あり → 指定ファイルのみをスコープとする
  - `$ARGUMENTS` なし → 変更ファイル全体をスコープとする
- **セルフチェックポイント**:
  - [ ] 認証情報パターンが diff に含まれていないことを確認した
  - [ ] 今回コミットするスコープ（対象ファイル集合）を確定した

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

### STEP 5: コミット分割計画

- **目的**: STEP 3 で確定したスコープを、**意味が成立する最小単位**へ分割し、各コミットのメッセージ・ステージング対象を計画する。レビューしやすい粒度（目安: 平均 200 行程度 / コミット）を狙う。
- **分割の原則**:
  1. **意味が成立する単位を最優先**。1 コミットは「単体で revert してもビルド・テストが壊れない、レビュアーが 1 つの意図として読める」単位にする。200 行はあくまで目安であり、論理単位を壊してまで行数に合わせない。
  2. **分割の優先順位**（粒度を上げる順）:
     - 関心事ごと（ドメインロジック / テスト / 設定 / ドキュメントなど type の異なる変更は別コミット）
     - レイヤーごと（domain → usecase → infrastructure → presentation の依存方向に沿って順序付け）
     - 機能・ファイル群ごと（独立した機能追加は分ける）
     - 1 ファイルが大きい場合は hunk 単位（`git apply --cached` で該当部分のみステージング）
  3. **順序**: 依存される側を先にコミットする（後のコミットが前のコミットに依存する向きに並べる）。
  4. 1 コミットが 200 行を大きく超える場合は、上記の優先順位で更に分割できないか検討する。分割不能な論理単位（例: 自動生成ファイル・大規模リネーム）はその旨を計画に明記する。
- **実行内容**:
  1. `git diff --stat`・ファイルごとの diff から変更を分類し、コミットの順序付きリストを作る
  2. 各コミットについて「ステージング対象（ファイルまたは hunk）」「行数概算」「コミットメッセージ案」を決める
- **メッセージ形式**（各コミット共通）:
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
  ## コミット分割計画（全 N コミット）

  ### コミット 1/N — 約 {行数} 行
  - ステージング対象: {ファイル / hunk 一覧}
  - メッセージ: {type}(bid_allocation_agent): {概要}

  ### コミット 2/N — 約 {行数} 行
  - ステージング対象: {ファイル / hunk 一覧}
  - メッセージ: {type}(bid_allocation_agent): {概要}

  ...
  ```
- **IF/ELSE**:
  - スコープが小さく 1 コミットが妥当（論理的に分割できない / 全体で 200 行程度以内） → N=1 の計画として提示
  - 分割可能 → 上記フォーマットで複数コミットの計画を提示
- **セルフチェックポイント**:
  - [ ] 各コミットが単体で意味が成立する論理単位になっている
  - [ ] 計画の全コミットを合算するとスコープ全体を過不足なくカバーしている
  - [ ] コミット順序が依存方向（依存される側が先）に沿っている

### STEP 5.5: メッセージ検証

- **目的**: 計画した**全コミット**のメッセージが Conventional Commits 形式に準拠していることを構文的に保証する。
- **実行内容**（計画の各メッセージについて実行）:
  ```bash
  MSG="{commit_message}"
  if echo "$MSG" | grep -Eq '^(feat|fix|docs|refactor|chore|test|ci)(\(.*\))?[!]?:\s.+'; then
    echo "VALID"
  else
    echo "INVALID"
  fi
  ```
- **IF/ELSE**:
  - 全て `VALID` → 次 STEP
  - いずれか `INVALID` → STEP 5 に戻り該当メッセージ再生成
- **セルフチェックポイント**:
  - [ ] 全コミットのメッセージで正規表現マッチを確認済み

### STEP 6: 分割計画のユーザー承認【USER_APPROVAL_REQUIRED】

- **IF/ELSE**:
  - 「OK」/ 承認 → STEP 7
  - 分割粒度・順序の修正指示 → STEP 5 に戻る
  - スコープ変更指示 → STEP 3 に戻る
- **セルフチェックポイント**:
  - [ ] ユーザーが分割計画全体に「OK」と明示した

### STEP 7: コミット実行ループ

- **目的**: 計画した各コミットを順番に作成する。**計画の先頭から 1 コミットずつ**、ステージング → コミットを繰り返す。
- **各コミットの実行内容**:
  1. そのコミット対象のみをステージングする（**他コミット分を巻き込まない**）:
     ```bash
     # ファイル単位の場合
     git add {このコミットのファイル}

     # ファイル内の一部 hunk のみの場合（git diff から該当 hunk を抽出したパッチを適用）
     git apply --cached {patch}
     ```
  2. `git diff --cached --stat` でステージング内容が計画どおりか確認する
  3. コミットを作成する:
     ```bash
     git commit -m "$(cat <<'EOF'
     {commit_message}

     Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
     EOF
     )"
     ```
  4. 残りの計画コミットがあれば次のコミットへ。全て完了するまで繰り返す。
- **セルフチェックポイント**（コミットごと）:
  - [ ] ステージング内容が計画のそのコミット分のみと一致している
  - [ ] `git commit` が exit=0 で完了した
- **セルフチェックポイント（ループ完了時）**:
  - [ ] 計画した全コミットを作成した
  - [ ] `git status --porcelain` で未コミットの変更（計画外）が残っていないことを確認した
  - [ ] `git log --oneline -{N}` で全コミットが計画どおり記録されていることを確認した
  - [ ] ユーザーに各コミットハッシュとメッセージを返却済み

---

## 5. AI 実装ノート（全体）

- **`git add -A` / `git add .` は使わない**: 意図しないファイル（`*.pyc`, `.env`, キャッシュ等）が混入する。必ず個別ファイル指定。
- **コミットは小さく・意味単位で**: STEP 5 の分割計画で論理単位（目安 平均 200 行 / コミット）に分け、STEP 7 のループで 1 コミットずつ作る。CI（STEP 4）はスコープ全体に対して 1 回実行すれば良く、コミットごとに pytest を再実行する必要はない。
- **hunk 単位の分割は `git apply --cached`**: `git add -p` はインタラクティブで Auto mode では停止するため使わない。`git diff {file}` の出力から該当 hunk のみを含むパッチを作り `git apply --cached` で適用する。
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
| 大量変更を 1 コミットに詰め込む | レビュー困難・revert/二分探索の粒度が粗い | STEP 5 で意味単位（目安 平均 200 行 / コミット）に分割する |
| `git add -p`（インタラクティブ） | Auto mode で停止し無音で skip される | hunk 単位は `git apply --cached` でパッチ適用 |

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
