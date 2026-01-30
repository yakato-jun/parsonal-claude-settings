#!/usr/bin/env python3
"""
SessionStart hook: compact 後に立ち止まってワークログの確認を促す。

動作:
  - SessionStart の source が "compact" の場合のみ発動
  - プロジェクトルート(cwd) の tmp/*/worklog.md を走査
  - ワークログの候補一覧を提示し、ユーザーに確認を促す指示を注入
  - ワークログの内容自体は注入しない（誤ったコンテキストの混入を防止）
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

    # ワークログ候補の一覧を構築
    candidates = []
    for wl in sorted(worklogs, key=lambda f: os.path.getmtime(f), reverse=True):
        dir_name = os.path.basename(os.path.dirname(wl))
        mtime = os.path.getmtime(wl)
        from datetime import datetime

        ts = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")
        candidates.append(f"  - {dir_name}/worklog.md (updated: {ts})")

    if candidates:
        candidate_list = "\n".join(candidates)
        message = (
            "[Compact Recovery] context compaction が発生しました。\n"
            "作業を再開する前に、ユーザーに確認してください。\n\n"
            "## 検出されたワークログ:\n"
            f"{candidate_list}\n\n"
            "## 必須アクション:\n"
            "AskUserQuestion を使って、以下をユーザーに確認すること:\n"
            "- どのワークログの作業を再開するか（または新規作業か）\n"
            "- 確認が取れたら、該当の worklog.md を Read で読み込んでから作業を再開する\n"
            "- ワークログ内の Tasks セクションの未完了タスクを TaskCreate で展開する\n\n"
            "**重要: ユーザーの確認なしに作業を再開しないこと。**"
        )
    else:
        message = (
            "[Compact Recovery] context compaction が発生しました。\n"
            "tmp/ 配下にワークログは見つかりませんでした。\n\n"
            "## 必須アクション:\n"
            "AskUserQuestion を使って、ユーザーに何の作業をしていたか確認すること。\n"
            "**重要: ユーザーの確認なしに作業を再開しないこと。**"
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
