#!/usr/bin/env python3
"""Exercise configuration reruns and bot-only writes in an isolated home."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="agent-dotfiles-test-")
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home),
                        GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0")
        self.env.pop("GIT_CONFIG_GLOBAL", None)
        self.env.pop("GIT_CONFIG_COUNT", None)
        (self.home / ".zshrc").write_text("# existing shell\n")
        (self.home / ".gitconfig").write_text("[user]\n name = personal-user\n")
        self.install()
        fake = self.home / "fake-bin"
        fake.mkdir()
        gh = fake / "gh"
        gh.write_text('#!/bin/sh\ncase "$1" in bot) exit 0;; api) echo "${TEST_GH_LOGIN:-dougbot-agent}";; *) exit 1;; esac\n')
        gh.chmod(0o755)
        self.env["PATH"] = f"{fake}:{self.home}/.local/bin:{os.environ['PATH']}"

    def tearDown(self):
        self.temp.cleanup()

    def run_command(self, *args, cwd=None):
        return subprocess.run(args, env=self.env, cwd=cwd or self.home,
                              capture_output=True, text=True)

    def install(self):
        result = self.run_command("/bin/bash", str(ROOT / "setup.sh"), "--link-only")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rerun_preserves_originals_and_does_not_duplicate_startup(self):
        original_backup = list((self.home / ".config/agent-worker/backups").glob("*/.zshrc"))
        self.assertEqual(len(original_backup), 1)
        self.assertEqual(original_backup[0].read_text(), "# existing shell\n")
        before = {name: (self.home / name).read_text()
                  for name in (".zshrc", ".zshenv", ".bash_profile", ".gitconfig")}
        self.install()
        after = {name: (self.home / name).read_text() for name in before}
        self.assertEqual(before, after)
        result = self.run_command("git", "dougbot", "config", "--get", "user.name")
        self.assertEqual(result.stdout.strip(), "dougbot-agent")
        shell = self.run_command("/bin/zsh", "-lc", 'command -v git-dougbot')
        self.assertEqual(shell.returncode, 0, shell.stderr)
        self.assertIn(str(self.home), shell.stdout)

    def test_bot_commit_and_refusal_of_other_github_identity(self):
        repo = self.home / "repo"
        result = self.run_command("git", "dougbot", "init", "-b", "main", str(repo))
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_command("git", "dougbot", "commit", "--allow-empty", "-m", "test", cwd=repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        author = self.run_command("git", "log", "-1", "--format=%an|%ae|%cn", cwd=repo)
        self.assertEqual(author.stdout.strip(), "dougbot-agent|269356667+dougbot-agent@users.noreply.github.com|dougbot-agent")
        self.env["TEST_GH_LOGIN"] = "personal-user"
        denied = self.run_command("git", "dougbot", "commit", "--allow-empty", "-m", "denied", cwd=repo)
        self.assertNotEqual(denied.returncode, 0)
        count = self.run_command("git", "rev-list", "--count", "HEAD", cwd=repo)
        self.assertEqual(count.stdout.strip(), "1")

    def test_local_author_override_is_rejected(self):
        repo = self.home / "repo"
        result = self.run_command("git", "dougbot", "init", "-b", "main", str(repo))
        self.assertEqual(result.returncode, 0, result.stderr)
        # Simulate an existing checkout's conflicting config without a Git write.
        with (repo / ".git/config").open("a") as config:
            config.write("\n[user]\n name = personal-user\n")
        denied = self.run_command("git", "dougbot", "commit", "--allow-empty", "-m", "denied", cwd=repo)
        self.assertNotEqual(denied.returncode, 0)
        self.assertIn("Effective Git author", denied.stderr)


    def test_doctor_reports_an_installed_but_broken_cli(self):
        binary = self.home / ".local/bin/codex"
        binary.write_text('#!/bin/sh\necho "cannot load runtime" >&2\nexit 1\n')
        binary.chmod(0o755)
        result = self.run_command("/bin/bash", str(ROOT / "scripts/check.sh"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("BROKEN  codex", result.stdout)


    def test_environment_is_stable_when_sourced_twice(self):
        command = '. "$HOME/.config/agent-worker/env.sh"; first="$PATH"; . "$HOME/.config/agent-worker/env.sh"; test "$first" = "$PATH"'
        result = self.run_command("/bin/bash", "-c", command)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
