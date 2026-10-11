# shellcheck shell=sh
# Portable PATH for interactive, SSH, and background worker shells.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:$HOME/.grok/bin:$HOME/.opencode/bin:/opt/homebrew/opt/node@24/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export EDITOR=nano
export VISUAL=nano
# Avoid macOS keychain access in SSH/background Cursor sessions.
export AGENT_CLI_CREDENTIAL_STORE=file
# N2's Muse accounts use its supported file backend.
export TBH_CREDENTIAL_BACKEND=file
# Optional machine-local credentials. This file must never enter the repository.
[ ! -r "$HOME/.config/agent-worker/provider-env.sh" ] || . "$HOME/.config/agent-worker/provider-env.sh"
# Older Cursor builds expose only the API-key environment input.
if [ -n "${CURSOR_AUTH_TOKEN:-}" ] && [ -z "${CURSOR_API_KEY:-}" ]; then
  export CURSOR_API_KEY="$CURSOR_AUTH_TOKEN"
fi
