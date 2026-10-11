#!/bin/bash
# Finish administrator-only work from the mini's own Terminal.
set -euo pipefail
STATE="$HOME/.config/agent-worker"
. "$STATE/env.sh"
APPLE=0
HOST=0
for option in "$@"; do
  case "$option" in
    --apple) APPLE=1 ;;
    --configure-host) HOST=1 ;;
    *) echo "Unknown option: $option" >&2; exit 2 ;;
  esac
done
if command -v cursor-agent >/dev/null && ! cursor-agent --version >/dev/null 2>&1; then
  echo 'Unlocking the login keychain so Cursor can run from SSH.'
  security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
fi
sudo -v
if [ "$HOST" = 1 ]; then
  sudo pmset -a sleep 0
  sudo pmset -a autorestart 1
fi
if [ "$APPLE" = 1 ]; then
  if [ ! -d /Applications/Xcode.app ]; then
    mas install 497799835
  fi
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
  /usr/bin/xcodebuild -version
fi
rm -f "$STATE/host-pending"
printf 'Administrator setup complete.\n'
