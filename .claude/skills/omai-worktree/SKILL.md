---
name: omai-worktree
description: OMAI Jira チケット (OMAI-XXXX) から git worktree を `/Users/s33533/dev/omai-worktrees/OMAI-XXXX` に作成し、適切なブランチ名 (`fix/`, `feat/`, `refactor/`, `chore/` プレフィックス + チケットの要約から派生した kebab-case 説明) で切って EnterWorktree で入るためのスキル。ユーザーが「OMAI-XXXX の worktree を作って」「OMAI-XXXX の調査ブランチを切って」「OMAI-XXXX で作業を始めたい」など OMAI チケット ID を出して worktree / ブランチ作成を求めたとき、たとえ「worktree」という単語が無くても必ず使うこと。Jira URL (https://ai-opetech.atlassian.net/browse/OMAI-XXXX) を貼られた場合も同様に使う。
---

# omai-worktree

OMAI プロジェクトの Jira チケットに対して、リポジトリの慣習に沿った worktree とブランチを作成するスキル。

## 前提

- リポジトリ root: `/Users/s33533/dev/omai-worktrees/main`
- worktree は `/Users/s33533/dev/omai-worktrees/OMAI-XXXX` の形で配置する (`main/.claude/worktrees/` 配下ではない)
- ブランチ命名は `<prefix>/OMAI-XXXX-<kebab-case-summary>`

既存例 (`git worktree list` で確認できる):

| ディレクトリ | ブランチ |
| --- | --- |
| `OMAI-1119` | `feat/OMAI-1119-yda-ad-daily-repository` |
| `OMAI-1623` | `fix/OMAI-1623-day-of-week-ratio-during-cooldown` |

## 手順

### 1. チケット情報の取得

ユーザーが提示したチケット ID (例: `OMAI-1637`) または Jira URL (`https://ai-opetech.atlassian.net/browse/OMAI-XXXX`) から ID を抽出する。

`mcp__atlassian__getJiraIssue` で取得する:

```
cloudId: "ai-opetech.atlassian.net"
issueIdOrKey: "OMAI-XXXX"
responseContentFormat: "markdown"
```

取得した `summary`, `labels`, `issuetype` をブランチ命名に使う。

### 2. ブランチプレフィックスの決定

`labels` と `summary` の内容から判定する:

- `"bug"` label を含む、または summary が `[fix]`, `バグ`, `修正` を含む → `fix/`
- `summary` が `リファクタ`, `refactor` を含む → `refactor/`
- `summary` が `chore`, `削除`, `更新` (依存・設定の更新系) を含む → `chore/`
- それ以外（新機能・改善） → `feat/`

判定が曖昧な場合は、上記のいずれを選んだか短くユーザーに伝えて確認する。「`fix/` でよいですか？」のような簡潔な確認。

### 3. kebab-case 説明の生成

summary から `[bid_allocation_agent]` のような prefix タグや、`OMAI-XXXX` のチケット番号を除去し、要点を 3〜6 語程度の英語 kebab-case にする。元の summary が日本語であっても、ブランチ名は英語 kebab-case にすること（既存ブランチがすべて英語のため）。

例:
- summary: `[bid_allocation_agent] 曜日係数 (day_of_week_rate) が連続日で累積される` → `day-of-week-rate-accumulation`
- summary: `[bid_allocation_agent] クールダウン中の曜日係数の扱い` → `day-of-week-ratio-during-cooldown`

### 4. worktree 作成

`Bash` ツールで以下を実行:

```
git worktree add /Users/s33533/dev/omai-worktrees/OMAI-XXXX -b <prefix>/OMAI-XXXX-<description> main
```

- ベースブランチは `main`
- 既にディレクトリ or ブランチが存在する場合 (`git worktree add` がエラーを返した場合) は、その旨をユーザーに伝えて指示を仰ぐ (上書きや削除を勝手にしない)

### 5. worktree に入る

`EnterWorktree` ツールを `path` パラメータ付きで呼ぶ:

```
path: "/Users/s33533/dev/omai-worktrees/OMAI-XXXX"
```

`name` パラメータは使わない (`name` を使うと `.claude/worktrees/` 配下になってしまう)。

### 6. 完了報告

ユーザーに以下を簡潔に伝える:

- チケットのタイトル・優先度・ステータス
- 作成したディレクトリパスとブランチ名
- チケット概要の要点 (description の冒頭〜真因部分) を 2〜4 行で要約
- 次に進めたいか確認（実装か、追加調査か）

## なぜこの形か

- **配置場所**: `main/.claude/worktrees/` 配下に作ると、メインリポジトリ内に worktree がネストして git status の挙動や CI スクリプトのパス前提が崩れる。チーム慣習として兄弟ディレクトリに配置する。
- **ブランチ命名**: GitHub PR 一覧でチケット ID と種別が一目で分かるように `<type>/OMAI-XXXX-<desc>` で統一されている。
- **英語 kebab-case**: 日本語ブランチ名は CI/CD やシェル補完で扱いづらいことがあり、既存ブランチはすべて英語。

## エッジケース

- **ID 抽出失敗**: URL からも ID らしき `OMAI-\d+` が見つからない場合はユーザーに確認する。
- **Jira 取得失敗** (権限・ネットワーク等): フォールバックとしてユーザーに summary とブランチ種別を聞く。
- **既存 worktree との衝突**: `git worktree list` で既に同名のディレクトリがある場合、削除や上書きを勝手にせず、`ExitWorktree` の `remove` で消すか別名で作るかをユーザーに確認する。
