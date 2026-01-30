#!/usr/bin/env python3
"""PostToolUse hook - 行動指針を定期的に注入

principles.txt から行動指針メッセージを読み込み、
指定回数のツール使用ごとにClaude Codeへ注入する。
"""
import json
import os
import sys

COUNTER_FILE = "/tmp/claude_tool_counter"
REMIND_EVERY = 5

# principles.txt のパス（このスクリプトと同じディレクトリ）
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PRINCIPLES_FILE = os.path.join(SCRIPT_DIR, "principles.txt")

# カウンター管理
count = int(open(COUNTER_FILE).read()) if os.path.exists(COUNTER_FILE) else 0
count += 1
open(COUNTER_FILE, "w").write(str(count))

if count % REMIND_EVERY == 0:
    if os.path.exists(PRINCIPLES_FILE):
        message = open(PRINCIPLES_FILE).read().strip()
    else:
        message = "[WARN] principles.txt が見つかりません: " + PRINCIPLES_FILE

    output = {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": message,
        }
    }
    print(json.dumps(output))

sys.exit(0)
