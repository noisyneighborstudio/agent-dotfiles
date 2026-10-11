#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$HOME/.config/agent-worker/env.sh"
STATE="$HOME/.config/agent-worker"
filtered=$(mktemp "$STATE/Brewfile.fleet.XXXXXX")
while IFS= read -r line; do
  case "$line" in
    'cask "t3-code@nightly"') [ ! -d '/Applications/T3 Code (Nightly).app' ] || continue ;;
    'cask "chatgpt"') [ ! -d /Applications/ChatGPT.app ] || continue ;;
    'cask "claude"') [ ! -d /Applications/Claude.app ] || continue ;;
    'cask "cursor"') [ ! -d /Applications/Cursor.app ] || continue ;;
    'cask "visual-studio-code"') [ ! -d '/Applications/Visual Studio Code.app' ] || continue ;;
    'cask "ghostty"') [ ! -d /Applications/Ghostty.app ] || continue ;;
    'cask "expo-orbit"') [ ! -d '/Applications/Expo Orbit.app' ] || continue ;;
  esac
  printf '%s\n' "$line" >> "$filtered"
done < "$ROOT/Brewfile.fleet"
brew bundle --file="$filtered" --no-upgrade
rm "$filtered"
uv python install --default 3.12
npm install -g --allow-scripts=@expo/ngrok,esbuild,workerd,protobufjs,dtrace-provider eas-cli wrangler @playwright/test @playwright/cli
playwright install chromium
if ! command -v t3 >/dev/null; then
  installer=$(mktemp)
  curl -fsSL https://t3.codes/install.sh -o "$installer"
  T3CODE_CHANNEL=nightly sh "$installer"
  rm "$installer"
fi
mkdir -p "$ANDROID_HOME"
for package in platform-tools emulator 'platforms;android-36' 'build-tools;36.0.0' 'system-images;android-36;google_apis;arm64-v8a'; do
  android --sdk="$ANDROID_HOME" sdk install "$package"
done
if ! android emulator list | grep -qx medium_phone; then
  android --sdk="$ANDROID_HOME" emulator create medium_phone
fi
if [ -d /Applications/Xcode.app ] && ! xcrun simctl list runtimes -j | python3 -c 'import json,sys; sys.exit(not any(r.get("isAvailable") and "iOS" in r["name"] for r in json.load(sys.stdin)["runtimes"]))'; then
  xcodebuild -downloadPlatform iOS -architectureVariant arm64
fi
# This service remains fully managed by T3. Load the user environment first.
bash "$ROOT/scripts/load-login-environment.sh"
t3 service install
python3 - "$ROOT" <<'PLIST'
from pathlib import Path
import plistlib,sys,subprocess,os
root=Path(sys.argv[1])
p=Path.home()/'Library/LaunchAgents/com.noisyneighbor.agent-worker.environment.plist'
data={'Label':'com.noisyneighbor.agent-worker.environment',
      'ProgramArguments':['/bin/bash',str(root/'scripts/load-login-environment.sh')],
      'RunAtLoad':True,
      'StandardOutPath':str(Path.home()/'Library/Logs/agent-worker/login-environment.log'),
      'StandardErrorPath':str(Path.home()/'Library/Logs/agent-worker/login-environment.log')}
p.parent.mkdir(parents=True,exist_ok=True)
p.write_bytes(plistlib.dumps(data));p.chmod(0o600)
domain='gui/'+str(os.getuid())
subprocess.run(['launchctl','bootout',domain,str(p)],capture_output=True)
subprocess.run(['launchctl','bootstrap',domain,str(p)],check=True)
PLIST
touch "$STATE/fleet-development"
printf '\nFull development profile installed. Run agent-doctor --full.\n'
