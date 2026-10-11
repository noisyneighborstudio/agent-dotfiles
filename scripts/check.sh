#!/bin/bash
set -uo pipefail
[ ! -f "$HOME/.config/agent-worker/env.sh" ] || . "$HOME/.config/agent-worker/env.sh"
missing=0
for binary in git gh node npm uv tmux rg jq claude codex grok bun agents; do
  if command -v "$binary" >/dev/null; then
    printf 'OK      %s\n' "$binary"
  else printf 'MISSING %s\n' "$binary"; missing=1; fi
done
for binary in claude codex grok bun cursor-agent opencode muse; do
  if command -v "$binary" >/dev/null; then
    if ! "$binary" --version >/dev/null 2>&1; then
      printf 'BROKEN  %s: executable failed to start\n' "$binary"
      missing=1
    fi
  fi
done
if [ -f "$HOME/.config/agent-worker/host-pending" ]; then
  echo 'PENDING administrator setup; run the finish-host helper in the mini Terminal'
  missing=1
fi
if [ "$(git dougbot config --get user.name 2>/dev/null)" = dougbot-agent ]; then
  echo 'OK      Git bot author'
else echo 'MISSING Git bot author'; missing=1; fi
# Read-only: no account switching or paid model requests.
if [ "$(gh api user --jq .login 2>/dev/null)" = dougbot-agent ]; then
  echo 'OK      GitHub bot credentials'
else echo 'MISSING GitHub bot credentials: sign in as dougbot-agent, then gh bot'; missing=1; fi
if command -v agents >/dev/null; then
  if auth=$(agents authed Default); then
    printf '%s\n' "$auth"
    for provider in claude codex grok; do
      if ! printf '%s\n' "$auth" | awk -F '\t' -v p="$provider" '$1 == p && $2 == "yes" {found=1} END {exit !found}'; then
        printf 'PENDING %s authentication is unverified\n' "$provider"
        missing=1
      fi
    done
  else missing=1; fi
  agents fleet status || missing=1
  agents fleet sync service status || missing=1
fi
echo 'Provider auth may be unknown. Verify access with one real job per provider.'
exit "$missing"
