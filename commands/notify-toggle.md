---
description: 通知音のON/OFFを切り替えます
runInShell: true
---

if [ -f ~/.claude/sound_enabled ]; then
  rm ~/.claude/sound_enabled
  echo "通知音: OFF"
else
  touch ~/.claude/sound_enabled
  echo "通知音: ON"
fi
