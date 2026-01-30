#!/usr/bin/env python3
"""
UserPromptSubmit hook: ユーザーの方向転換を検出し、stale な TaskList のクリアを促す。

動作:
  - ユーザーのプロンプト冒頭2行に方向転換フレーズが含まれるか判定
  - 検出した場合、TaskList の確認・クリアを促す指示を additionalContext に注入
"""

import json
import re
import sys

# 冒頭2行で検出するフレーズ（部分一致）
TRIGGER_PHRASES = [
    "ちょっとまってください",
    "ちょっと待ってください",
    "違います",
    "なにやってるんですか",
    "何やってるんですか",
    "そうではなく",
]

# 正規表現パターン（大文字小文字無視）
TRIGGER_PATTERNS = [
    re.compile(r"\bno\b", re.IGNORECASE),
]


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        return

    prompt = hook_input.get("prompt", "")
    if not prompt:
        return

    # 冒頭2行のみチェック
    lines = prompt.strip().splitlines()[:2]
    check_text = "\n".join(lines)

    triggered = any(phrase in check_text for phrase in TRIGGER_PHRASES)

    if not triggered:
        triggered = any(p.search(check_text) for p in TRIGGER_PATTERNS)

    if not triggered:
        return

    message = (
        "[Direction Change] ユーザーが方向転換・中断を示唆しています。\n\n"
        "## 必須アクション（ユーザーの指示に応答する前に実行）:\n"
        "1. TaskList を呼び出して現在のタスク一覧を確認する\n"
        "2. pending / in_progress のタスクがあれば、"
        "ユーザーの新しい指示と無関係なタスクを TaskUpdate で completed にしてクリアする\n"
        "3. クリアした場合は「以前のタスクをクリアしました」と一言伝える\n"
        "4. その上で、ユーザーの新しい指示に対応する\n\n"
        "**古いタスクリストを引きずって実行しないこと。**"
    )

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": message,
        }
    }

    json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
