#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# uninstall.sh - install.sh で作成した symlink を削除する
#
# 動作:
#   - このリポジトリを指す symlink のみを削除（他のファイルには触れない）
#   - .bak バックアップがあれば復元
#   - settings.json から hook 登録を削除
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# symlink を1つ削除する
unlink_file() {
  local rel_path="$1"
  local src="${REPO_DIR}/${rel_path}"
  local dst="${CLAUDE_DIR}/${rel_path}"

  # symlink でない、またはこのリポジトリを指していない場合はスキップ
  if [ ! -L "$dst" ]; then
    warn "symlinkではありません（スキップ）: ${dst}"
    return 0
  fi

  if [ "$(readlink -f "$dst")" != "$(readlink -f "$src")" ]; then
    warn "このリポジトリを指していません（スキップ）: ${dst}"
    return 0
  fi

  rm "$dst"
  info "リンク削除: ${rel_path}"

  # .bak があれば復元
  local backup="${dst}.bak"
  if [ -f "$backup" ]; then
    mv "$backup" "$dst"
    info "バックアップを復元: ${backup} -> ${dst}"
  fi
}

echo "=== parsonal-claude-settings uninstall ==="
echo "リポジトリ: ${REPO_DIR}"
echo "対象:       ${CLAUDE_DIR}"
echo ""

for f in "${REPO_DIR}"/commands/*.md; do
  [ -f "$f" ] || continue
  unlink_file "commands/$(basename "$f")"
done

for f in "${REPO_DIR}"/agents/*.md; do
  [ -f "$f" ] || continue
  unlink_file "agents/$(basename "$f")"
done

for f in "${REPO_DIR}"/hooks/*; do
  [ -f "$f" ] || continue
  unlink_file "hooks/$(basename "$f")"
done

for f in "${REPO_DIR}"/assets/*; do
  [ -f "$f" ] || continue
  unlink_file "assets/$(basename "$f")"
done

# --- settings.json から hook 登録を削除 ---
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  python3 - "$SETTINGS_FILE" "$CLAUDE_DIR" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
claude_dir = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

# このリポジトリが管理する hook command の一覧
managed_commands = {
    f"python3 {claude_dir}/hooks/remind-principles.py",
    f"python3 {claude_dir}/hooks/restore-worklog-on-compact.py",
}

hooks = settings.get("hooks", {})
changed = False

for event_name in list(hooks.keys()):
    entries = hooks[event_name]
    original_len = len(entries)
    filtered = [
        entry for entry in entries
        if not any(h.get("command") in managed_commands for h in entry.get("hooks", []))
    ]
    if len(filtered) < original_len:
        hooks[event_name] = filtered
        changed = True
        print(f"  {event_name}: エントリを削除しました")
    else:
        print(f"  {event_name}: 該当エントリなし（スキップ）")
    # イベントが空になったら削除
    if not hooks[event_name]:
        del hooks[event_name]

# hooks 自体が空になったら削除
if "hooks" in settings and not settings["hooks"]:
    del settings["hooks"]

if changed:
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    print("  settings.json を更新しました")
PYEOF
fi

echo ""
echo "アンインストール完了しました。"
