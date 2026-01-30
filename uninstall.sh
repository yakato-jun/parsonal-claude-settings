#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# uninstall.sh - install.sh で作成した symlink を削除する
#
# 動作:
#   - このリポジトリを指す symlink のみを削除（他のファイルには触れない）
#   - .bak バックアップがあれば復元
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

echo ""
echo "アンインストール完了しました。"
