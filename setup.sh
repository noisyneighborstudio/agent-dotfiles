#!/bin/bash
# Compatible with macOS's built-in Bash 3.2.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
STATE="$HOME/.config/agent-worker"
MODE=install
CONTAINERS=0
APPLE=0
EXTRAS=0
HOST=0
N2_CHANNEL=continuous
for arg in "$@"; do
  case "$arg" in
    --link-only) MODE='link' ;;
    --check) MODE=check ;;
    --containers) CONTAINERS=1 ;;
    --apple) APPLE=1 ;;
    --extras) EXTRAS=1 ;;
    --configure-host) HOST=1 ;;
    --n2-stable) N2_CHANNEL=stable ;;
    --help|-h)
      echo 'Usage: bash setup.sh [--link-only|--check] [--containers] [--apple] [--extras] [--configure-host] [--n2-stable]'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
say() { printf '\n%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }
if [ "$MODE" = check ]; then exec /bin/bash "$ROOT/scripts/check.sh"; fi
[ "$(uname -s)" = Darwin ] || die 'Run on macOS.'
[ "$(uname -m)" = arm64 ] || die 'Use a native Apple silicon terminal, outside Rosetta.'
[ "$(id -u)" != 0 ] || die 'Run as the worker account. Do not sudo the entire script.'
mkdir -p "$STATE/backups" "$HOME/.local/bin" "$HOME/Developer" "$HOME/dispatch-inbox" "$HOME/Library/Logs/agent-worker"
BACKUP="$STATE/backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACKUP"
backup() {
  if [ -e "$1" ] || [ -L "$1" ]; then cp -pP "$1" "$BACKUP/$(basename "$1")"; fi
}
link_file() {
  local src=$1 dest=$2
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then return; fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    [ ! -d "$dest" ] || die "Won't replace directory: $dest"
    backup "$dest"
    rm "$dest"
  fi
  ln -s "$src" "$dest"
}
append_once() {
  local line=$1 file=$2
  if ! grep -qxF "$line" "$file" 2>/dev/null; then
    backup "$file"
    printf '\n%s\n' "$line" >> "$file"
  fi
}
managed_file() {
  local dest=$1 tmp
  tmp=$(mktemp "$STATE/generated.XXXXXX")
  cat > "$tmp"
  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then rm "$tmp"; return; fi
  [ ! -d "$dest" ] || die "Won't replace directory: $dest"
  backup "$dest"
  rm -f "$dest"
  mv "$tmp" "$dest"
}
if [ "$MODE" = install ]; then
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
    die 'Finish the Command Line Tools dialog, then rerun this same command.'
  fi
  if [ ! -x /opt/homebrew/bin/brew ]; then
    say 'Installing Homebrew. Initial setup needs administrator access.'
    installer=$(mktemp "$STATE/homebrew.XXXXXX")
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    /bin/bash "$installer"
    rm "$installer"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  say 'Installing core worker packages.'
  filtered=$(mktemp "$STATE/Brewfile.XXXXXX")
  while IFS= read -r line; do
    case "$line" in
      'cask "tailscale"') [ ! -d /Applications/Tailscale.app ] || continue ;;
      'cask "google-chrome"') [ ! -d '/Applications/Google Chrome.app' ] || continue ;;
    esac
    printf '%s\n' "$line" >> "$filtered"
  done < "$ROOT/Brewfile"
  brew bundle --file="$filtered" --no-upgrade
  rm "$filtered"
fi
link_file "$ROOT/shell/env.sh" "$STATE/env.sh"
link_file "$ROOT/git/gitignore" "$STATE/gitignore"
# The literal $HOME is intentionally expanded by the future shell.
# shellcheck disable=SC2016
append_once '. "$HOME/.config/agent-worker/env.sh"' "$HOME/.zshenv"
# shellcheck disable=SC2016
append_once '. "$HOME/.config/agent-worker/env.sh"' "$HOME/.bash_profile"
managed_file "$HOME/.zshrc" <<EOF
# Managed by agent-dotfiles. Local additions go in ~/.zshrc.local.
source "$ROOT/shell/interactive.zsh"
EOF
. "$STATE/env.sh"
# Dedicated worker account: plain Git also authors as the bot.
managed_file "$HOME/.gitconfig" <<EOF
[include]
    path = $STATE/bot.gitconfig
[alias]
    dougbot = "!git-dougbot"
EOF
managed_file "$STATE/bot.gitconfig" <<EOF
[include]
    path = $ROOT/git/base.gitconfig
[user]
    name = dougbot-agent
    email = 269356667+dougbot-agent@users.noreply.github.com
[credential "https://github.com"]
    helper =
    helper = !gh auth git-credential
EOF
link_file "$ROOT/scripts/git-dougbot" "$HOME/.local/bin/git-dougbot"
managed_file "$HOME/.local/bin/agent-doctor" <<EOF
#!/bin/bash
exec /bin/bash "$ROOT/scripts/check.sh" "\$@"
EOF
chmod +x "$ROOT/scripts/git-dougbot" "$HOME/.local/bin/agent-doctor"
say "Portable shell and bot Git settings installed. Backups: $BACKUP"
[ "$MODE" != link ] || exit 0
if [ "$(npm config get prefix)" != "$HOME/.npm-global" ]; then
  backup "$HOME/.npmrc"
  npm config set prefix "$HOME/.npm-global"
fi
say 'Installing Claude Code, Codex, Grok, and Bun.'
if ! command -v claude >/dev/null; then
  installer=$(mktemp "$STATE/claude.XXXXXX")
  curl -fsSL https://claude.ai/install.sh -o "$installer"
  /bin/bash "$installer" stable
  rm "$installer"
fi
command -v codex >/dev/null || npm install -g @openai/codex
command -v grok >/dev/null || npm install -g @xai-official/grok
command -v bun >/dev/null || npm install -g bun
uv python install 3.12
say "Installing verified N2 Agents from the $N2_CHANNEL feed."
python3 "$ROOT/scripts/install-n2.py" "$N2_CHANNEL"
link_file '/Applications/N2 Agents.app/Contents/Resources/agents' "$HOME/.local/bin/agents"
agents shims
if ! agents fleet id >/dev/null 2>&1; then agents fleet init --machine "$(hostname -s)"; fi
# Starts only the native sync service. No peers or credentials are shared.
agents fleet sync service install --interval 300
if [ "$EXTRAS" = 1 ]; then
  for pair in 'cursor-agent|https://cursor.com/install' 'opencode|https://opencode.ai/install' 'muse|https://dev.meta.ai/install.sh'; do
    binary=${pair%%|*}; url=${pair#*|}
    if ! command -v "$binary" >/dev/null; then
      installer=$(mktemp "$STATE/extra.XXXXXX")
      curl -fsSL "$url" -o "$installer"
      /bin/bash "$installer"
      rm "$installer"
    fi
  done
  agents shims
fi
if [ "$CONTAINERS" = 1 ]; then
  brew install colima docker docker-compose
  mkdir -p "$HOME/.docker/cli-plugins"
  link_file /opt/homebrew/opt/docker-compose/bin/docker-compose "$HOME/.docker/cli-plugins/docker-compose"
  colima status >/dev/null 2>&1 || colima start --cpu 4 --memory 6 --disk 60
  brew services start colima
fi
if [ "$APPLE" = 1 ]; then
  brew install mas cocoapods watchman
  if [ ! -d /Applications/Xcode.app ]; then
    mas install 497799835 || die 'Sign into the Mac App Store, then rerun with --apple.'
  fi
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
fi
if [ "$HOST" = 1 ]; then
  sudo pmset -a sleep 0
  sudo pmset -a autorestart 1
fi
if ! gh alias list | grep -q '^bot:'; then
  gh alias set bot 'auth switch --hostname github.com --user dougbot-agent'
fi
say 'Installed. Complete these account-specific steps:'
printf '%s\n' \
  '1. Open Tailscale and sign in.' \
  '2. Enable Remote Login for this account in System Settings > General > Sharing.' \
  '3. Enable Screen Sharing if needed.' \
  '4. Run claude, codex login, and grok to sign in.' \
  '5. Run gh auth login --hostname github.com --git-protocol https as dougbot-agent.' \
  '6. Run gh bot, then agent-doctor. Pair N2 using README.md.' \
  '7. Start a new terminal, reboot once, and verify remote access.'
