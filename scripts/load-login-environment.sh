#!/bin/bash
set -euo pipefail
. "$HOME/.config/agent-worker/env.sh"
# Keep private values out of plist files and logs.
for key in PATH JAVA_HOME ANDROID_HOME ANDROID_SDK_ROOT AGENT_CLI_CREDENTIAL_STORE TBH_CREDENTIAL_BACKEND CURSOR_AUTH_TOKEN CURSOR_API_KEY; do
  value=$(printenv "$key" 2>/dev/null || true)
  [ -z "$value" ] || launchctl setenv "$key" "$value"
done
if launchctl print "gui/$(id -u)/com.t3tools.t3code.service" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/com.t3tools.t3code.service"
fi
