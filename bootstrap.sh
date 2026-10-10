#!/bin/bash
# Fresh-machine entry point. Downloads source without requiring Git credentials.
set -euo pipefail
DEST="$HOME/agent-dotfiles"
run_setup() {
  # A curl-piped bootstrap still needs a terminal for Homebrew and sudo prompts.
  if [ -t 1 ]; then
    /bin/bash "$DEST/setup.sh" "$@" </dev/tty
  else
    /bin/bash "$DEST/setup.sh" "$@"
  fi
}
if [ -f "$DEST/setup.sh" ]; then
  printf 'Using existing setup at %s\n' "$DEST"
  run_setup "$@"
  exit 0
fi
[ ! -e "$DEST" ] || { echo "$DEST exists without setup.sh; move it aside first." >&2; exit 1; }
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
curl -fsSL https://github.com/noisyneighborstudio/agent-dotfiles/archive/refs/heads/main.tar.gz -o "$TEMP/source.tar.gz"
mkdir "$TEMP/source"
tar -xzf "$TEMP/source.tar.gz" --strip-components=1 -C "$TEMP/source"
[ -f "$TEMP/source/setup.sh" ] || { echo 'Archive is missing setup.sh.' >&2; exit 1; }
mv "$TEMP/source" "$DEST"
run_setup "$@"
