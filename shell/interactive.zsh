# Curated from Seth's local dotfiles, inspected 2026-10-10.
autoload -Uz compinit && compinit
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
PROMPT='%F{cyan}%n@%m%f %F{blue}%~%f %# '
alias ll='eza -la --git'
alias gs='git status'
alias gd='git diff'
alias glog='git log --oneline --graph --decorate'
alias gc='git dougbot commit'
alias gp='git dougbot push'
alias ..='cd ..'
alias ...='cd ../..'
alias br='bun run'
alias bi='bun install'
alias bt='bun test'
alias cc='claude'
alias simpaste='xcrun simctl pbsync host booted'
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v fzf >/dev/null && source <(fzf --zsh)
[[ -f '/Applications/N2 Agents.app/Contents/Resources/agents.zsh' ]] && source '/Applications/N2 Agents.app/Contents/Resources/agents.zsh'
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
