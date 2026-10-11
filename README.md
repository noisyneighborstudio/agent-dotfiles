# Set up a Mac mini agent worker

Run Claude, Codex, Grok, and N2 Agents on a dedicated Apple silicon Mac. This replaces the full workstation bootstrap in `sethwebster/dotfiles`.

## Install

Log into the worker account. It needs administrator access during initial Homebrew and system setup. Do not sudo the whole script.

Download this repository without Git credentials first:

```bash
curl -fsSL https://raw.githubusercontent.com/noisyneighborstudio/agent-dotfiles/main/bootstrap.sh | bash -s -- --configure-host
```

You can also unzip the supplied download and run `bash setup.sh --configure-host` inside it. Keep that folder in place: the shell files link to it.

If Command Line Tools are missing, complete the install dialog and rerun the last command.

The default installs Homebrew, Git and Git LFS, GitHub CLI, Node 24 LTS, Python 3.12 through uv, Bun, tmux, shell utilities, Chrome, Tailscale, Claude, Codex, Grok, and N2 Agents. N2 uses the continuous feed to match the current main Mac. The app must pass signature verification and match its verified signing team. Use `--n2-stable` on a fresh install for stable instead.

Rerunning skips existing tools and retains an installed N2 app. Changed configuration files are backed up under `~/.config/agent-worker/backups`. Existing agent binaries are not upgraded automatically. Setup logs are saved under `~/Library/Logs/agent-worker`.

Add tools only when your jobs need them:

```bash
# Containers through Colima, without Docker Desktop.
bash ~/agent-dotfiles/setup.sh --containers

# Xcode, CocoaPods, and Watchman. Requires App Store sign-in.
bash ~/agent-dotfiles/setup.sh --apple

# Cursor agent, OpenCode, and Muse.
bash ~/agent-dotfiles/setup.sh --extras
```

For an unattended SSH run, administrator steps are deferred if sudo cannot authenticate. Run the printed `scripts/finish-host.sh` command in the mini's own Terminal to enter the password. The helper also unlocks the login keychain when Cursor cannot start. `agent-doctor` reports these steps as pending and checks that installed agent binaries actually start.

Combine flags as needed. `--configure-host` disables system sleep and enables restart after power failure. It does not change FileVault, automatic login, or remote-access permissions. `--link-only` installs configuration without packages or services. `--check` reports commands and bot credentials.

## Sign in and enable access

1. Open Tailscale and sign in.
2. In System Settings > General > Sharing, enable Remote Login for the worker account. Enable Screen Sharing for GUI access.
3. Start a new terminal. Run `claude`, `codex login`, and `grok` and complete each sign-in.
4. Run `gh auth login --hostname github.com --git-protocol https`. Sign in as **dougbot-agent**. Run `gh bot`, then `agent-doctor`.
5. Run one small task with each provider. The doctor does not make paid model requests.

The script installs N2's per-user fleet sync LaunchAgent. It needs the worker account's logged-in session. A service failure stops setup rather than claiming readiness.

Create extra profile slots when needed:

```bash
agents new Work --vendors claude,codex,grok
agents login Work --vendor claude
agents login Work --vendor codex
agents login Work --vendor grok
```

No account credentials, provider profiles, SSH private keys, or fleet trust state are copied from the main Mac.

## Pair N2 with the main Mac

Check the installed app's pairing interface:

```bash
agents fleet help
agents fleet id
```

On the main Mac, initialize its identity if needed. Mint an invite bound to the mini's peer ID and record the main Mac's SSH host public key:

```bash
agents fleet init
agents fleet invite --peer MINI_PEER_ID
agents fleet id --host-key
```

On the mini, join with the main Mac's Tailscale address, account name, invite code, and host public key:

```bash
agents fleet join --to MAIN_MAC_TAILSCALE_NAME --user MAIN_MAC_USER --code INVITE_CODE --host-key 'MAIN_MAC_HOST_PUBLIC_KEY'
agents fleet status
```

Review profile, tool, and credential sharing policies in N2 before enabling them. Bootstrap does not approve peers or share credentials.

## Use bot Git identity

Plain Git and `git dougbot` use the bot author on this dedicated account. The wrapper verifies the effective author, switches GitHub CLI with `gh bot`, and checks `gh api user --jq .login` before repository writes. Local identity overrides can make the wrapper refuse to run.

```bash
git dougbot config --get user.name
gh bot
gh api user --jq .login
git dougbot clone https://github.com/sethwebster/YOUR_REPO.git ~/Developer/YOUR_REPO
```

Use `git dougbot` for commits, tags, pushes, and clones. Run `gh bot` before GitHub CLI writes. Use a separate Git worktree per job.

## Customize the worker

Put shell additions in `~/.zshrc.local`. Put projects in `~/Developer`, outside iCloud sync. Existing `.zshrc` and `.gitconfig` are backed up. Existing `.zshenv` and `.bash_profile` keep their contents and receive one environment-source line.

The portable settings come from the local `~/dotfiles` checkout inspected on October 10, 2026: navigation aliases, Git formatting, history, Bun shortcuts, and simulator paste. The full workstation shell, automatic update jobs, old runtime pins, personal Git identity, hardcoded home paths, permission-bypass aliases, and personal application list are not activated.

After a reboot, verify SSH, Tailscale, N2 service status, and one provider job. Tailscale on macOS needs a logged-in session. Keeping FileVault requires a recovery route that works before that session starts. See [Tailscale unattended access](https://tailscale.com/docs/how-to/run-unattended) and [Apple FileVault guidance](https://support.apple.com/en-gb/guide/deployment/dep82064ec40/1/web/1.0).

## Installation sources

- [Homebrew](https://docs.brew.sh/Installation)
- [Claude Code](https://code.claude.com/docs/en/setup)
- [Codex CLI](https://developers.openai.com/codex/cli/)
- [Grok CLI](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/npm/grok/README.md)
- [N2 Agents](https://github.com/noisyneighborstudio/n2-agents)

## Verify changes

Run the configuration tests on macOS. They use a temporary home, simulate GitHub identity responses, and exercise real Git commits. They do not install packages or modify the current account.

```bash
python3 tests/test_config.py
shellcheck -x -e SC1091 bootstrap.sh setup.sh scripts/git-dougbot scripts/check.sh shell/env.sh
```

## Install the full development profile

For a complete fleet-development worker, add `--fleet-dev`:

```bash
curl -fsSL https://raw.githubusercontent.com/noisyneighborstudio/agent-dotfiles/main/bootstrap.sh | bash -s -- --fleet-dev
```

This includes the existing core, extra agents, containers, Apple tools, T3 Code Nightly and its native background service, ChatGPT, Claude, Cursor, VS Code, Ghostty, Expo Orbit, pnpm, EAS, Wrangler, Playwright with Chromium, CMake, Ninja, Rust, Go, Java 17, media/document tools, and Android SDK/emulator support. It also installs an iOS simulator runtime when Xcode is present.

The private login environment is loaded before T3 starts so GUI/background jobs can use the same approved accounts as SSH. No credentials enter this repository. New machines still need provider and cloud sign-ins; copying credentials is a separate explicit authorization step.

Verify the complete profile, rather than only agent executables:

```bash
agent-doctor --full
python3 ~/agent-dotfiles/scripts/verify-builds.py
```

After installing this profile, plain `agent-doctor` automatically runs the full check. The full check verifies signed app bundles, command availability, T3 service health, mobile SDKs, container runtime, cloud authentication, and bot identity. The build check compiles and runs C, Swift, Rust, Go, and Java, then compiles, installs, and launches a test iOS app on a booted simulator. The latest results are saved privately under `~/.config/agent-worker`.

T3's service binds to loopback. For access from your main Mac, forward its port through the existing SSH connection:

```bash
ssh -L 3773:127.0.0.1:3773 agent-sh-m5
```

Use T3's normal one-time pairing flow to authorize the receiving browser or app. The Nightly desktop app and CLI follow the same channel. Full GUI sign-ins, release signing, and project-specific secrets remain separate from installing development tools.
