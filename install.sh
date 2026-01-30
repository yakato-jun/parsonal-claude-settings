#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# install.sh - ~/.claude/ へ symlink をデプロイする
#
# 使い方:
#   git clone https://github.com/yakato-jun/parsonal-claude-settings.git ~/parsonal-claude-settings
#   cd ~/parsonal-claude-settings
#   ./install.sh
#
# 動作:
#   - commands/, agents/, hooks/ 内のファイルを ~/.claude/ の対応ディレクトリに symlink
#   - 既存の通常ファイルがあれば .bak を付けてバックアップ
#   - 既に正しい symlink があればスキップ（冪等）
#   - hooks の登録を ~/.claude/settings.json に追加
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

# 色付き出力（端末でなければ無効）
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# symlink を1つ作成する
# $1: リポジトリ内の相対パス (例: commands/self-review.md)
link_file() {
  local rel_path="$1"
  local src="${REPO_DIR}/${rel_path}"
  local dst="${CLAUDE_DIR}/${rel_path}"
  local dst_dir
  dst_dir="$(dirname "$dst")"

  # ソースファイル存在チェック
  if [ ! -f "$src" ]; then
    error "ソースが見つかりません: ${src}"
    return 1
  fi

  # 宛先ディレクトリ作成
  mkdir -p "$dst_dir"

  # 既に正しい symlink ならスキップ
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    info "既にリンク済み: ${rel_path}"
    return 0
  fi

  # 既存の通常ファイルをバックアップ
  if [ -f "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.bak"
    warn "既存ファイルをバックアップ: ${dst} -> ${backup}"
    mv "$dst" "$backup"
  fi

  # 既存の壊れた/異なる symlink を削除
  if [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$src" "$dst"
  info "リンク作成: ${rel_path}"
}

echo "=== parsonal-claude-settings install ==="
echo "リポジトリ: ${REPO_DIR}"
echo "反映先:     ${CLAUDE_DIR}"
echo ""

# commands/ 内の .md ファイル
for f in "${REPO_DIR}"/commands/*.md; do
  [ -f "$f" ] || continue
  link_file "commands/$(basename "$f")"
done

# agents/ 内の .md ファイル
for f in "${REPO_DIR}"/agents/*.md; do
  [ -f "$f" ] || continue
  link_file "agents/$(basename "$f")"
done

# hooks/ 内のファイル
for f in "${REPO_DIR}"/hooks/*; do
  [ -f "$f" ] || continue
  link_file "hooks/$(basename "$f")"
done

# assets/ 内のファイル
for f in "${REPO_DIR}"/assets/*; do
  [ -f "$f" ] || continue
  link_file "assets/$(basename "$f")"
done

# --- グローバル settings.json に hook 登録を追加 ---
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

# settings.json が存在しなければ空オブジェクトで作成
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# python3 が使えることを前提に hook 設定をマージ
python3 - "$SETTINGS_FILE" "$CLAUDE_DIR" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
claude_dir = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
changed = False


def register_hook(event_name, entry):
    """指定イベントに hook エントリを登録（重複チェック付き）"""
    global changed
    event_hooks = hooks.setdefault(event_name, [])
    # entry 内の command を抽出して重複チェック
    new_commands = {h["command"] for h in entry.get("hooks", [])}
    already_exists = any(
        any(h.get("command") in new_commands for h in e.get("hooks", []))
        for e in event_hooks
    )
    if already_exists:
        print(f"  {event_name}: 既に登録済み")
    else:
        event_hooks.append(entry)
        changed = True
        print(f"  {event_name}: 登録しました")


# PostToolUse: remind-principles
register_hook("PostToolUse", {
    "matcher": "Edit|Write|Bash",
    "hooks": [
        {
            "type": "command",
            "command": f"python3 {claude_dir}/hooks/remind-principles.py"
        }
    ]
})

# SessionStart: restore-worklog-on-compact
register_hook("SessionStart", {
    "hooks": [
        {
            "type": "command",
            "command": f"python3 {claude_dir}/hooks/restore-worklog-on-compact.py"
        }
    ]
})

# UserPromptSubmit: detect-direction-change
register_hook("UserPromptSubmit", {
    "hooks": [
        {
            "type": "command",
            "command": f"python3 {claude_dir}/hooks/detect-direction-change.py"
        }
    ]
})

if changed:
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    print("  settings.json を更新しました")
PYEOF

echo ""
echo "完了しました。"
