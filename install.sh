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
#   - commands/, agents/, hooks/, output-styles/, globals/ 内のファイルを ~/.claude/ の対応ディレクトリに symlink
#   - globals/ 内の .md は ~/.claude/ 直下に配置し、CLAUDE.md にインポート行を追記
#   - 既存の通常ファイルがあれば .bak を付けてバックアップ
#   - 既に正しい symlink があればスキップ（冪等）
#   - hooks の ~/.claude/settings.json への登録は --with-hooks 指定時のみ
#     （hooks ファイルの symlink は常に作成する。登録だけが opt-in）
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

# hooks の settings.json 登録は opt-in（既定は hooks 無効運用のため登録しない）
WITH_HOOKS=0
for arg in "$@"; do
  case "$arg" in
    --with-hooks) WITH_HOOKS=1 ;;
    *) echo "不明なオプション: $arg"; echo "使い方: ./install.sh [--with-hooks]"; exit 1 ;;
  esac
done

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

# output-styles/ 内の .md ファイル
for f in "${REPO_DIR}"/output-styles/*.md; do
  [ -f "$f" ] || continue
  link_file "output-styles/$(basename "$f")"
done

# globals/ 内の .md ファイル → ~/.claude/ 直下に配置
for f in "${REPO_DIR}"/globals/*.md; do
  [ -f "$f" ] || continue
  local_name="$(basename "$f")"
  src="${REPO_DIR}/globals/${local_name}"
  dst="${CLAUDE_DIR}/${local_name}"

  # 既に正しい symlink ならスキップ
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    info "既にリンク済み: ${local_name}"
  else
    # 既存の通常ファイルをバックアップ
    if [ -f "$dst" ] && [ ! -L "$dst" ]; then
      warn "既存ファイルをバックアップ: ${dst} -> ${dst}.bak"
      mv "$dst" "${dst}.bak"
    fi
    # 既存の壊れた/異なる symlink を削除
    if [ -L "$dst" ]; then
      rm "$dst"
    fi
    ln -s "$src" "$dst"
    info "リンク作成: ${local_name} (globals/)"
  fi
done

# CLAUDE.md にインポート行を追記する関数
inject_claude_md_import() {
  local filename="$1"
  local claude_md="${CLAUDE_DIR}/CLAUDE.md"

  if [ ! -f "$claude_md" ]; then
    warn "CLAUDE.md が見つかりません: ${claude_md}"
    return 1
  fi

  # 既に存在すればスキップ（コメントアウトされたものは除外）
  if grep -qE "^@${filename}$" "$claude_md"; then
    info "CLAUDE.md: @${filename} は既に登録済み"
    return 0
  fi

  # Custom Imports セクションがなければ作成
  if ! grep -q "# Custom Imports" "$claude_md"; then
    printf '\n# Custom Imports\n' >> "$claude_md"
  fi
  echo "@${filename}" >> "$claude_md"
  info "CLAUDE.md: @${filename} を追記しました"
}

# globals/ 内の .md ファイルのインポート行を登録
for f in "${REPO_DIR}"/globals/*.md; do
  [ -f "$f" ] || continue
  inject_claude_md_import "$(basename "$f")"
done

# --- グローバル settings.json に hook 登録を追加（--with-hooks 指定時のみ） ---
if [ "$WITH_HOOKS" -eq 0 ]; then
  info "hooks の settings.json 登録をスキップ（--with-hooks で有効化）"
  echo ""
  echo "完了しました。"
  exit 0
fi

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
