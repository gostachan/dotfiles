#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "slack-sdk>=3.27",
# ]
# ///
"""ope-tech times チャンネルの過去6ヶ月分スレッド数 (= トップレベル投稿数) を集計し、レポートチャンネルへ投稿する。

Keychain 取得元:
  service: ope-times-report
  account: default
  password: JSON 形式の設定
    {
      "bot_token": "xoxb-...",
      "channels": ["C0123...", "C0456..."],
      "report_channel": "C0789..."
    }

必要な Bot Token スコープ:
  channels:history, channels:read, chat:write
  (private channel も対象に含む場合は groups:history, groups:read も)
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

JST = ZoneInfo("Asia/Tokyo")
KEYCHAIN_SERVICE = "ope-times-report"
KEYCHAIN_ACCOUNT = "default"
MONTHS_BACK = 6


def load_config() -> dict:
    result = subprocess.run(
        [
            "security", "find-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", KEYCHAIN_ACCOUNT,
            "-w",
        ],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout.strip())


def past_months_range(now: datetime, months: int) -> tuple[datetime, datetime]:
    """当月を含めず、直近 ``months`` 個の完了済み月をカバーする半開区間 [start, end) を返す。"""
    end = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    year = end.year
    month = end.month - months
    while month <= 0:
        month += 12
        year -= 1
    start = end.replace(year=year, month=month)
    return start, end


def call_with_retry(fn, *args, **kwargs):
    for attempt in range(5):
        try:
            return fn(*args, **kwargs)
        except SlackApiError as e:
            if e.response.get("error") == "ratelimited":
                wait = int(e.response.headers.get("Retry-After", "5"))
                time.sleep(wait)
                continue
            raise
    raise RuntimeError("Slack API retry exhausted")


def count_threads(client: WebClient, channel_id: str, oldest: float, latest: float) -> int:
    """期間内の「スレッド数」を返す。

    各トップレベル投稿 (= conversations.history が返すメッセージ) を 1 スレッドとして数える。
    スレッド内の reply はカウントしない。
    bot/join/leave などの subtype 付きシステムメッセージは除外する。
    """
    count = 0
    cursor: str | None = None
    while True:
        kwargs = {
            "channel": channel_id,
            "oldest": str(oldest),
            "latest": str(latest),
            "limit": 200,
        }
        if cursor:
            kwargs["cursor"] = cursor
        resp = call_with_retry(client.conversations_history, **kwargs)

        for msg in resp["messages"]:
            if msg.get("subtype") is None:
                count += 1

        if resp.get("has_more"):
            cursor = resp["response_metadata"]["next_cursor"]
        else:
            break
    return count


def get_channel_name(client: WebClient, channel_id: str) -> str:
    resp = call_with_retry(client.conversations_info, channel=channel_id)
    return resp["channel"]["name"]


def main() -> int:
    cfg = load_config()
    token = cfg["bot_token"]
    channel_ids: list[str] = cfg["channels"]
    report_channel: str = cfg["report_channel"]

    client = WebClient(token=token)

    now = datetime.now(JST)
    start, end = past_months_range(now, MONTHS_BACK)
    last_month = end - timedelta(days=1)
    period_label = f"{start.strftime('%Y-%m')} 〜 {last_month.strftime('%Y-%m')}"

    results: list[tuple[str, int | str]] = []
    total = 0
    for ch in channel_ids:
        try:
            name = get_channel_name(client, ch)
            n = count_threads(client, ch, start.timestamp(), end.timestamp())
        except SlackApiError as e:
            print(f"[error] channel={ch}: {e}", file=sys.stderr)
            results.append((ch, f"error:{e.response.get('error', 'unknown')}"))
            continue
        results.append((name, n))
        total += n

    results.sort(key=lambda x: (-x[1]) if isinstance(x[1], int) else 0)

    lines = [
        f"*🗓 {period_label} ope-tech times 稼働レポート (過去{MONTHS_BACK}ヶ月)*",
        f"対象チャンネル数: {len(channel_ids)}　合計スレッド数: *{total:,}*",
        "",
    ]
    for name, n in results:
        if isinstance(n, int):
            lines.append(f"• `#{name}` — {n:,}")
        else:
            lines.append(f"• `{name}` — {n}")
    text = "\n".join(lines)

    call_with_retry(
        client.chat_postMessage,
        channel=report_channel,
        text=text,
        unfurl_links=False,
        unfurl_media=False,
    )
    print(f"Posted to {report_channel}: {period_label} threads={total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
