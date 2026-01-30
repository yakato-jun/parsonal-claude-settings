#!/usr/bin/env python3
"""
SessionStart hook: compact 後にアクティブなワークログを additionalContext として注入する。

動作:
  - SessionStart の source が "compact" の場合のみ発動
  - プロジェクトルート(cwd) の tmp/*/worklog.md を走査
  - 最新の worklog.md の内容を additionalContext に注入
  - ワークログがない場合は何もしない
"""

import glob
import json
import os
import sys


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        return

    if hook_input.get("source") != "compact":
        return

    cwd = hook_input.get("cwd", "")
    if not cwd:
        return

    # tmp/*/worklog.md を検索
    pattern = os.path.join(cwd, "tmp", "*", "worklog.md")
    worklogs = glob.glob(pattern)

    if not worklogs:
        return

    # 更新日時でソート（最新が先頭）
    worklogs.sort(key=lambda f: os.path.getmtime(f), reverse=True)
    most_recent = worklogs[0]

    try:
        with open(most_recent) as f:
            content = f.read()
    except Exception:
        return

    # 長すぎる場合は切り詰め（additionalContext の実用的な上限）
    max_chars = 8000
    if len(content) > max_chars:
        content = content[:max_chars] + "\n\n... (truncated)"

    message = (
        "[Compact Recovery] context compaction が発生しました。\n"
        "直前まで作業していたワークログを自動で読み込みました。\n\n"
        f"## Active Worklog: {most_recent}\n\n"
        f"{content}\n\n"
        "---\n"
        "上記ワークログの Tasks セクションを確認し、"
        "未完了タスクがあれば TaskCreate で展開してから作業を再開してください。"
    )

    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": message,
        }
    }

    json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
