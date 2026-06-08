# ope-times-report

ope-tech チームの times チャンネル群の**過去6ヶ月分のスレッド数 (= トップレベル投稿数)** を集計し、レポートチャンネルへ投稿する launchd ジョブ。

毎月 1日 10:00 (JST) に自動実行されます。

## 構成

| ファイル | 役割 |
| --- | --- |
| `report.py` | 集計本体。PEP 723 inline metadata で `slack-sdk` を宣言し `uv run` で実行 |
| `run.sh` | launchd から呼ばれるラッパ。nix-darwin/home-manager の `PATH` を明示して `uv run` |
| `com.s33533.ope-times-report.plist` | launchd plist テンプレート (`__SCRIPT_DIR__` は install 時に置換) |
| `install.sh` | install / uninstall / run-now / setup-secret / status のヘルパー |

## 集計仕様

- 範囲: 当月の 6ヶ月前 `00:00 JST 1日` 〜 当月 `00:00 JST 1日` (exclusive)。完了済みの直近 6 ヶ月をカバー
- カウント対象: 各チャンネルの**トップレベル投稿数** (= スレッド数)。スレッド内の reply はカウントしない。`subtype` 付きメッセージ (join/leave/bot 通知など) は除外
- 出力: スレッド数降順で「合計」+「`#channel-name` — 件数」の Slack mrkdwn
- 範囲の月数は `report.py` の定数 `MONTHS_BACK` で変更可能

## セットアップ

### 1. Slack App と Bot Token を用意

Slack App を作成し、以下の Bot Token Scope を付与する。

- `channels:history` — public channel の履歴取得
- `channels:read` — channel 情報取得
- `chat:write` — レポート投稿
- `groups:history`, `groups:read` — 対象に private channel を含める場合

ワークスペースにインストールし、Bot Token (`xoxb-...`) を取得。
**対象 times チャンネルと通知先チャンネルの両方に bot を invite** しておく。

### 2. Keychain に設定を登録

Bot Token、対象チャンネル ID リスト、通知先チャンネル ID をひとつの JSON にまとめて Keychain に保存する。

```sh
./install.sh setup-secret
```

実行後に標準入力で以下の JSON を貼り付けて `Ctrl-D`:

```json
{
  "bot_token": "xoxb-...",
  "channels": ["C0123ABCD", "C0456EFGH"],
  "report_channel": "C0789IJKL"
}
```

Keychain 上の格納先:

- service: `ope-times-report`
- account: `default`

確認: `./install.sh show-secret`
削除: `./install.sh delete-secret`

### 3. launchd に登録

```sh
./install.sh install
```

`~/Library/LaunchAgents/com.s33533.ope-times-report.plist` を生成し、`launchctl bootstrap gui/$UID` で登録する。

### 4. 動作確認

スケジュールを待たずに即時実行:

```sh
./install.sh run-now
cat run.log
```

レポートチャンネルに投稿が来ていれば成功。

## 運用コマンド

| コマンド | 内容 |
| --- | --- |
| `./install.sh install` | plist 配置 + bootstrap |
| `./install.sh uninstall` | bootout + plist 削除 |
| `./install.sh run-now` | 即時実行 (`launchctl kickstart -k`) |
| `./install.sh status` | `launchctl print` でジョブ状態を表示 |
| `./install.sh setup-secret` | Keychain に JSON を登録 / 更新 |
| `./install.sh show-secret` | Keychain の中身を表示 |
| `./install.sh delete-secret` | Keychain から削除 |

ログは `run.log` に追記される (`.gitignore` 済み)。

## スケジュール変更

`com.s33533.ope-times-report.plist` の `StartCalendarInterval` を編集して `./install.sh install` を再実行する。

```xml
<key>StartCalendarInterval</key>
<dict>
  <key>Day</key><integer>1</integer>
  <key>Hour</key><integer>10</integer>
  <key>Minute</key><integer>0</integer>
</dict>
```

実行時刻に Mac がスリープ/停止していた場合、launchd の仕様で次回起動時に遅延実行される。

## トラブルシュート

- **`run.log` に `security: ... exit status 44`** — Keychain にエントリが無い。`./install.sh setup-secret` を実行
- **`not_in_channel` エラー** — bot が対象チャンネルに invite されていない
- **`missing_scope` エラー** — Slack App の Bot Token Scope を見直して再インストール
- **`uv: command not found`** — `run.sh` の `PATH` を確認。nix-darwin 環境では `/run/current-system/sw/bin` に `uv` がある想定
