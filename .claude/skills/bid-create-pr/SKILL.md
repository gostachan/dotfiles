---
name: bid-create-pr
description: bid_allocation_agent パッケージの Pull Request を作成するガイド
model: claude-opus-4-7
---

# Pull Request 作成ガイド

コミット済み差分のみを対象に、CI が全て通過した状態で Pull Request を作成するスキル。Auto mode でも CI スキップが発生しないよう、AI 自身が CI を実行し exit code を STEP 進行条件として扱う。

---

## 1. 最優先ルール（ハードガードレール）

| # | ルール | 違反時の影響 |
|---|--------|-------------|
| 1 | **未コミットの変更（staged / unstaged）は一切含めない**。`git status --porcelain` が空でなければ作業中断 | PR に関係ない変更が push され、レビュー混乱 |
| 2 | **CI（ruff format / ruff check / pyright / pytest）を AI 自身が Bash で実行し、全て exit=0 でなければ push しない** | CI 失敗 PR が発生し CI パイプを無駄消費 |
| 3 | **PR タイトルは Conventional Commits 準拠かつ末尾に Jira チケット番号 `(OMAI-XXXX)` を含める**（`/^(feat\|fix\|docs\|refactor\|chore\|test\|ci)(\(.*\))?[!]?:\s.+\s\(OMAI-[0-9]+(,\s*OMAI-[0-9]+)*\)$/` にマッチ） | Release Drafter が PR を分類できない / PR と Jira のトラッキングが切れる |
| 4 | **`main` ブランチ上での実行は禁止** | 誤ってメインから PR を立てる事故 |
| 5 | **ユーザー承認なしで push / `gh pr create` を実行しない** | 未レビューの PR が量産される |
| 6 | **`/bid-code-review` を STEP 3.5 で AI 自身が Skill ツール経由で起動**し、**Critical / Major の指摘を 0 件**にしてから push する（Minor / Suggestion を残置する場合はユーザー承認＋PR 本文への明記必須） | セルフレビュー漏れの低品質 PR が公開される |

---

## 2. 入力パラメータ・モード判定

| 条件 | モード | 進行 STEP |
|------|--------|----------|
| `$ARGUMENTS` でブランチ名指定 | 指定ブランチモード | STEP 1 → 7 |
| `$ARGUMENTS` なし、現在ブランチが `main` 以外 | 現在ブランチモード | STEP 1 → 7 |
| `$ARGUMENTS` なし、現在ブランチが `main` | **エラー**（中断） | ユーザーに対象ブランチを求める |

| 項目 | 値 |
|------|-----|
| ベースブランチ | `main`（固定） |
| 差分範囲 | `main...HEAD`（コミット済みのみ） |

---

## 3. 使用ツール一覧

| 用途 | 推奨ツール | 禁止ツール・操作 |
|------|-----------|-----------------|
| 現在ブランチ検出 | `Bash(git branch --show-current)` | - |
| コミット済み差分取得 | `Bash(git diff main...HEAD)` / `Bash(git log main..HEAD --oneline)` | `git diff`（ワーキングツリー）や `git diff --cached`（ステージング） |
| 未コミット検出 | `Bash(git status --porcelain)` | 目視判定 |
| CI 実行 | `Bash(uv run ruff format --check .)` 等 | ユーザーに実行依頼のみ（Auto mode で skip 危険） |
| PR テンプレート読込 | `Read(.github/PULL_REQUEST_TEMPLATE.md)` | - |
| PR 作成 | `Bash(gh pr create ...)` | Web UI 手動作成 |

---

## 4. ワークフロー

### STEP 1: 対象ブランチの特定

- **目的**: どのブランチから PR を立てるか確定する。
- **実行内容**:
  ```bash
  git branch --show-current
  ```
- **IF/ELSE**:
  - 現在ブランチが `main` → **エラー中断**。`AskUserQuestion` で対象ブランチを求める
  - `$ARGUMENTS` でブランチ指定あり → そのブランチに切り替え
  - `$ARGUMENTS` なし → 現在ブランチを使用
- **セルフチェックポイント**:
  - [ ] `git branch --show-current` の結果が `main` 以外
  - [ ] ブランチが `origin` に存在しない場合、後の push で `-u` フラグが必要であることを認識している

### STEP 2: 差分と origin/main の鮮度確認

- **目的**: ベースが古すぎないか確認し、必要なら rebase を提案する。
- **実行内容**:
  ```bash
  git fetch origin main
  git log main..HEAD --oneline
  git diff main...HEAD --stat
  MERGE_BASE=$(git merge-base HEAD origin/main)
  BEHIND_COUNT=$(git rev-list --count $MERGE_BASE..origin/main)
  ```
- **IF/ELSE**:
  - `BEHIND_COUNT` が 20 以上（= origin/main が 20 コミット以上進んでいる）→ **ユーザーに rebase を提案**（「`git rebase origin/main` を実行しますか？」）
  - それ以下 → そのまま次 STEP
- **セルフチェックポイント**:
  - [ ] コミット済み差分が 1 件以上ある
  - [ ] 差分内容が作業内容と一致している

### STEP 2.5: 未コミット変更の検出

- **目的**: ステージング中・未ステージの変更が混在していないことを保証する。
- **実行内容**:
  ```bash
  git status --porcelain
  ```
- **IF/ELSE**:
  - 出力が空 → 次 STEP
  - 出力が非空 → **処理中断**。ユーザーに以下を提示:
    ```
    未コミットの変更が検出されました:
    {git status --porcelain の出力}

    対応を選択してください:
    1. これらの変更を新しいコミットに含める
    2. 変更を退避（stash）してから PR 作成
    3. 中断する
    ```
- **セルフチェックポイント**:
  - [ ] `git status --porcelain` の出力が空

### STEP 3: CI の自動実行【AI 自身が実行する】

- **目的**: 全ての CI チェックを AI 自身が実行し、パスしたことを exit code で検証する。
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
  - いずれか非ゼロ → **修正ループに入る**。エラーを Read/Edit/Bash で修正 → 再実行 → 全て exit=0 まで繰り返す
- **セルフチェックポイント（全て必須）**:
  - [ ] `ruff format --check` exit=0
  - [ ] `ruff check` exit=0
  - [ ] `pyright` exit=0
  - [ ] `pytest` exit=0
- **AI 実装ノート**:
  - **ユーザーに「コマンド貼り付けを依頼」はしない**。Bash で直接実行すること
  - テストが既に失敗している状態で `/bid-create-pr` が呼ばれた場合は、まず修正してから push

### STEP 3.5: `/bid-code-review` の自動実行【AI 自身が実行する】

- **目的**: CI 通過後、PR 公開前に `/bid-code-review` スキルを Skill ツール経由で起動し、**全重大度の指摘を 0 件**（または残置 Minor / Suggestion がユーザー承認済み）にしてから進行する。セルフレビュー漏れによる低品質 PR の公開を防ぐ。
- **実行内容**:
  1. `Skill(skill: "bid-code-review")` を引数なしで起動（現在ブランチモード = `main...HEAD` を対象とする）
  2. レビュー結果から `Critical` / `Major` / `Minor` / `Suggestion` の件数を抽出
- **IF/ELSE**:
  - **全重大度が 0 件**（Critical = 0 **かつ** Major = 0 **かつ** Minor = 0 **かつ** Suggestion = 0）→ 次 STEP
  - いずれかが 1 件以上 → **修正ループに入る**:
    1. 指摘内容に従って Edit / Write で修正
    2. 修正を **新規コミット** として追加（`--amend` は使わない。CLAUDE.md の規約に従う）
    3. STEP 3 の CI を再実行（修正で CI が壊れる可能性のため）
    4. STEP 3.5 を再実行
    5. 全重大度が 0 件になるまで繰り返し（**最大 3 反復** で打ち切り）
  - 3 反復後も残った指摘の処理:
    - **Critical または Major が 1 件以上残存** → **中断**して `AskUserQuestion` で判断を仰ぐ。ユーザーの明示的な承認なしに次 STEP へ進まない（PR 公開不可）
    - **Minor / Suggestion のみ残存** → `AskUserQuestion` で各指摘について「修正する / このまま残す（残置理由を必須記載）」を確認。「残す」と判断された指摘は STEP 5 の PR 本文に **`既知の未対応事項`** セクションを追加し、`指摘内容` と `残置理由` を併記してから次 STEP に進む
- **セルフチェックポイント（全て必須）**:
  - [ ] `/bid-code-review` を Skill ツール経由で起動した
  - [ ] レビュー結果が以下のいずれかを満たす:
    - 全重大度（Critical / Major / Minor / Suggestion）が 0 件
    - もしくは Critical / Major = 0 件 **かつ** Minor / Suggestion 残置時はユーザー承認済み + PR 本文 `既知の未対応事項` セクションに記載済み
  - [ ] 修正コミットを追加した場合、STEP 3 の CI を再実行している
- **スキップ条件**:
  - **スキップ不可**: 変更カテゴリに関わらず `/bid-code-review` は必ず起動する
- **AI 実装ノート**:
  - **ユーザーに「`/bid-code-review` を実行してください」と依頼しない**。Skill ツールで直接起動する
  - Auto mode でも skip 厳禁（重要レビューが無音で抜ける）
  - 修正ループは無限再帰を防ぐため最大 3 反復で打ち切る
  - Minor / Suggestion でも「修正コストが高く効果が小さい」「現スコープ外」と判断されるケースがあるため、ユーザー承認による残置パスを設けている。Critical / Major には残置パスは無い
  - `/bid-code-review` 自体が変更ファイルを Read で確認するため、コミット済みであることを前提とする（未コミット変更がある場合 STEP 2.5 で既に中断済み）

### STEP 4: PR テンプレートの読み込み

- **目的**: 本文フォーマットを確定する。
- **実行内容**:
  ```
  Read(.github/PULL_REQUEST_TEMPLATE.md)
  ```
- **IF/ELSE**:
  - テンプレート存在 → 本文ベースとして採用
  - 存在しない → STEP 5 のデフォルトフォーマット使用

### STEP 5: PR 内容の提案

- **目的**: タイトル・本文のドラフトをユーザーに提示する。
- **タイトル生成ルール**:
  - ブランチ名プレフィックス（`feat/`, `fix/` 等）を Conventional Commits プレフィックスにマッピング
  - 形式: `{prefix}(bid_allocation_agent): {変更内容の要約} (OMAI-XXXX)`
  - **末尾に Jira チケット番号 `(OMAI-XXXX)` を必ず含める**。PR / コミット / Jira の三者トラッキング維持のため
  - チケット番号はブランチ名（`<prefix>/OMAI-XXXX-...`）から自動抽出する。複数チケットを含む場合はカンマ区切りで列挙（例: `(OMAI-1111, OMAI-1112)`）
  - ブランチ名から番号が取得できない場合は `AskUserQuestion` で確認する
  - 例: `feat(bid_allocation_agent): 予算計算ロジックを改善 (OMAI-1493)`
- **本文生成ルール**:
  - PR テンプレートがある場合: テンプレート構造に沿って各項目を埋める
  - ない場合のデフォルト:
    ```markdown
    ## 概要
    {コミット群から抽出した変更要約}

    ## 変更内容
    - {コミットメッセージから抽出}

    ## 関連
    - 親チケット: OMAI-{番号}
    - 親エピック: OMAI-{番号} ({エピックの概要})
    - 仕様書: Confluence {ページ ID} {§ 該当節}
    - 依存 (merge 済み): {依存 PR タイトル} #{PR 番号} ({Jira チケット番号}) {一言補足}
    - 並走 (open): {並走 PR タイトル} #{PR 番号} ({Jira チケット番号} / {対象媒体等}) — {本 PR との関係や rebase 計画}
    {該当項目がない場合は当該行を省略。「関連」セクション全体が空になる場合は「なし」と記載}

    ## レビュー観点
    {レビュアーに重点的に見てほしい箇所と、その理由（設計判断・トレードオフ・懸念点など）を記載。なければ「特になし」}

    ## 動作確認
    - [x] ruff format チェック完了
    - [x] ruff check 完了
    - [x] pyright 型チェック完了
    - [x] pytest テスト完了
    - [x] /bid-code-review 実行（Critical / Major: 0 件）
    - 追加で確認したケース（任意）: {CI 以外で実機 / 統合テスト / 本番影響範囲などを検証したもの}

    ## リスク・留意事項
    - **未検証 / 想定外のケース**: {再現できなかった条件・本番データ依存など}
    - **既知のリスク**: {本変更で発生し得る副作用・後方互換性・パフォーマンス懸念など}
    {該当なしの項目は省略。すべて空なら「なし」と記載}

    ## 既知の未対応事項
    {STEP 3.5 でユーザー承認のもと残置となった Minor / Suggestion を以下フォーマットで列挙。なければ「なし」と記載}
    - [{重大度}] {ファイル:行}: {指摘内容} — 残置理由: {ユーザーから提示された理由}
    ```
- **「関連」セクションの埋め方**:
  - **親チケット**: ブランチ名（`<prefix>/OMAI-XXXX-...`）から番号を抽出。複数チケットを含むコミットがある場合はカンマ区切りで列挙
  - **親エピック**: ユーザーから明示された場合のみ記載。不明な場合は `AskUserQuestion` で確認する
  - **仕様書**: ユーザーから明示された場合のみ記載（Confluence ページ ID + 該当節など）
  - **依存 (merge 済み)**: 本 PR がベースとする既存マージ済み PR。`gh pr list --search "is:merged ..."` などで候補を探し、ユーザーに確認
  - **並走 (open)**: 同時進行中で関係する open PR。マージ順・コンフリクト解消方針があれば末尾に追記する
  - いずれも **推測で勝手に埋めない**。情報が無い項目は `AskUserQuestion` で確認し、ユーザーが「該当なし」と回答した行は省略する
- **「レビュー観点」セクションの埋め方**:
  - **目的**: レビュアーが「どこを集中して見ればよいか」を一目で把握できるようにし、レビュー負荷を分散・効率化する
  - **書き方**: フリーフォーム 1 項目。差分から AI が**設計判断・ロジック密度が高い箇所**（条件分岐・新規ロジック・トレードオフ判断など）を抽出してユーザーに提案し、ユーザー承認のうえで「`xxx.py` の retry ロジックを 3 回固定にした。指数バックオフでも良いか見てほしい」のような自然文で記載する
  - **推測で勝手に埋めない**。明らかな観点が無い場合は「特になし」と記載
- **「動作確認」セクションの埋め方**:
  - CI 4 種（ruff format / ruff check / pyright / pytest）と `/bid-code-review` は STEP 3・3.5 で実行済みのため自動でチェックを入れる
  - **追加で確認したケース**: ユーザーが手元で実機 / 統合テスト / 本番影響範囲などを検証している場合のみ `AskUserQuestion` で確認して記載。CI 以外の検証がない場合はこの行を省略
- **「リスク・留意事項」セクションの埋め方**:
  - **未検証 / 想定外のケース**: 「再現できなかった」「本番データ依存で検証できない」など正直に書く。`AskUserQuestion` でユーザーから取得し、**「なし」と推測で書かない**
  - **既知のリスク**: ユーザーが意識している副作用・後方互換性・パフォーマンス懸念などを `AskUserQuestion` で取得
  - 両項目とも該当なしの場合は「なし」と記載
- **提示フォーマット**:
  ```
  ## PR 作成提案

  ### ブランチ
  {branch} → main

  ### タイトル
  {title}

  ### 本文
  {body}
  ```

### STEP 5.5: タイトル検証

- **目的**: タイトルが Conventional Commits 準拠かつ末尾に Jira チケット番号 `(OMAI-XXXX)` を含むことを構文的に保証する。
- **実行内容**:
  ```bash
  TITLE="{title}"
  if echo "$TITLE" | grep -Eq '^(feat|fix|docs|refactor|chore|test|ci)(\(.*\))?[!]?:\s.+\s\(OMAI-[0-9]+(,\s*OMAI-[0-9]+)*\)$'; then
    echo "VALID"
  else
    echo "INVALID"
  fi
  ```
  - 末尾 `(OMAI-XXXX)` を必須化（複数チケットは `(OMAI-1111, OMAI-1112)` の形式で許容）
- **IF/ELSE**:
  - `VALID` → 次 STEP
  - `INVALID` → STEP 5 に戻りタイトル再生成
- **セルフチェックポイント**:
  - [ ] タイトル正規表現マッチを確認済み
  - [ ] `{prefix}` が `feat` / `fix` / `docs` / `refactor` / `chore` / `test` / `ci` のいずれか
  - [ ] 末尾に `(OMAI-XXXX)` 形式の Jira チケット番号を含む

### STEP 6: ユーザー承認【USER_APPROVAL_REQUIRED】

- **IF/ELSE**:
  - 「OK」/ 承認 → STEP 7
  - 修正指示 → STEP 5 に戻る
- **セルフチェックポイント**:
  - [ ] ユーザーが「OK」と明示した

### STEP 7: PR 作成の実行

- **実行内容**:
  ```bash
  git push -u origin {branch}

  gh pr create \
    --title "{title}" \
    --body "$(cat <<'EOF'
  {body}
  EOF
  )" \
    --base main \
    --head {branch}
  ```
- **セルフチェックポイント**:
  - [ ] `gh pr create` の出力に PR URL が含まれている
  - [ ] ユーザーに PR URL を返却済み

---

## 5. AI 実装ノート（全体）

- **`git diff`（ワーキングツリー差分）は絶対に使わない**: 未コミット変更が混入する。常に `main...HEAD` でコミット済みに限定。
- **STEP 3 は skip 厳禁**: Auto mode では「コマンドを提示してユーザーの貼り付けを待つ」パターンは無音で skip されるため、必ず Bash で直接実行する。
- **タイトル生成でブランチ名を流用する場合**: `feat/OMAI-1234-improve-budget-calc` → `feat(bid_allocation_agent): 予算計算の改善` のように、プレフィックスを保持して内容を人間可読に翻訳する。
- **rebase 提案のタイミング**: STEP 2 で `BEHIND_COUNT >= 20` を閾値にしているが、コンフリクトが発生したら即座にユーザー確認。

---

## 6. 禁止事項

| 禁止行為 | 理由 | 正しい対応 |
|---------|------|-----------|
| 未コミット変更を含めた PR 作成 | レビュアーが実際の変更内容を把握できない | STEP 2.5 で検出・中断 |
| CI 失敗のまま push | CI パイプ浪費・レビュアーへの失礼 | STEP 3 で exit=0 を担保してから進行 |
| 非 Conventional Commits タイトル / Jira 番号欠落 | リリースノート分類失敗 / PR と Jira のトラッキング切断 | STEP 5.5 で正規表現マッチ検証（末尾 `(OMAI-XXXX)` 必須） |
| `main` ブランチから PR | ベースと head が同一でエラー | STEP 1 でエラー中断 |
| `gh pr create --no-verify` 相当の強行 | CI 回避の悪手 | 必ず CI パスさせる |
| `/bid-code-review` 未実行で PR 作成 | セルフレビュー無しでレビュアーに負荷集中・品質低下 | STEP 3.5 で必ず実行・全重大度を 0 件（Minor / Suggestion 残置時はユーザー承認＋PR 本文への明記必須）にする |

---

## 7. 利用例

```
# 現在ブランチから PR 作成
/bid-create-pr

# ブランチ指定で PR 作成
/bid-create-pr feat/OMAI-1234-improve-budget-calc
```

---

## 8. リソース

### 関連スキル

- `/bid-code-review` — PR 作成前のセルフレビュー（STEP 3.5 で AI 自身が Skill ツール経由で起動）

### 関連ファイル

- `.github/PULL_REQUEST_TEMPLATE.md` — PR 本文テンプレート
- `.github/labeler.yml` — `bid-allocation-agent` ラベルの自動付与設定
