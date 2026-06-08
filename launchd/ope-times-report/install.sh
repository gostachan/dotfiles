#!/bin/sh
# launchd ジョブのインストール/アンインストール/手動実行ヘルパー
#
# 使い方:
#   ./install.sh setup-secret  # Keychain に bot_token/channels/report_channel を JSON で登録
#   ./install.sh install       # plist を ~/Library/LaunchAgents/ にデプロイし bootstrap
#   ./install.sh uninstall     # bootout して plist を削除
#   ./install.sh run-now       # スケジュール待たずに即時実行
#   ./install.sh status        # 現状確認
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.s33533.ope-times-report"
PLIST_TEMPLATE="$SCRIPT_DIR/$LABEL.plist"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_INSTALLED="$LAUNCH_AGENTS/$LABEL.plist"
DOMAIN="gui/$(id -u)"

KEYCHAIN_SERVICE="ope-times-report"
KEYCHAIN_ACCOUNT="default"

generate_plist() {
  sed "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" "$PLIST_TEMPLATE" > "$PLIST_INSTALLED"
}

cmd="${1:-help}"

case "$cmd" in
  install)
    mkdir -p "$LAUNCH_AGENTS"
    generate_plist
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$PLIST_INSTALLED"
    echo "Installed: $PLIST_INSTALLED"
    echo "次回実行: 毎月 1日 10:00 (JST)"
    ;;

  uninstall)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST_INSTALLED"
    echo "Uninstalled"
    ;;

  run-now)
    if [ ! -f "$PLIST_INSTALLED" ]; then
      echo "未インストールです。先に ./install.sh install を実行してください。" >&2
      exit 1
    fi
    launchctl kickstart -k "$DOMAIN/$LABEL"
    echo "kicked. ログ: $SCRIPT_DIR/run.log"
    ;;

  status)
    launchctl print "$DOMAIN/$LABEL" 2>&1 | sed -n '1,60p' || true
    ;;

  setup-secret)
    cat <<'USAGE'
以下の JSON を Keychain に登録します。

  {
    "bot_token": "xoxb-...",
    "channels": ["C0123ABCD", "C0456EFGH"],
    "report_channel": "C0789IJKL"
  }

入力後 Ctrl-D で終了:
USAGE
    payload="$(cat)"
    # JSON が壊れていないか検証
    printf '%s' "$payload" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' \
      || { echo "JSON のパースに失敗しました" >&2; exit 1; }
    security add-generic-password \
      -s "$KEYCHAIN_SERVICE" \
      -a "$KEYCHAIN_ACCOUNT" \
      -U \
      -w "$payload"
    echo "Keychain に保存しました (service=$KEYCHAIN_SERVICE account=$KEYCHAIN_ACCOUNT)"
    ;;

  show-secret)
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w
    ;;

  delete-secret)
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT"
    ;;

  help|*)
    sed -n '2,9p' "$0"
    ;;
esac
