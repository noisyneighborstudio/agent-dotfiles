# shellcheck shell=sh
# Portable PATH for interactive, SSH, GUI service, and background worker shells.
agent_prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
for agent_directory in /opt/homebrew/sbin /opt/homebrew/bin /opt/homebrew/opt/node@24/bin "$HOME/.opencode/bin" "$HOME/.grok/bin" "$HOME/.bun/bin" "$HOME/.npm-global/bin" "$HOME/.local/bin"; do
  agent_prepend_path "$agent_directory"
done
export EDITOR=nano VISUAL=nano
export AGENT_CLI_CREDENTIAL_STORE=file
export TBH_CREDENTIAL_BACKEND=file
[ ! -r "$HOME/.config/agent-worker/provider-env.sh" ] || . "$HOME/.config/agent-worker/provider-env.sh"
if [ -n "${CURSOR_AUTH_TOKEN:-}" ] && [ -z "${CURSOR_API_KEY:-}" ]; then
  export CURSOR_API_KEY="$CURSOR_AUTH_TOKEN"
fi
if [ -d /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home ]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
  agent_prepend_path "$JAVA_HOME/bin"
fi
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
agent_prepend_path "$ANDROID_HOME/emulator"
agent_prepend_path "$ANDROID_HOME/platform-tools"
# Normalize an inherited PATH too, so repeated sourcing has a stable result.
PATH=$(printf '%s' "$PATH" | /usr/bin/awk -v RS=: 'length($0) && !seen[$0]++ {path=path separator $0; separator=":"} END {printf "%s",path}')
export PATH
unset agent_directory
