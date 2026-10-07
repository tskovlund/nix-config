{ pkgs, ... }:

{
  # Claude Code — AI coding assistant CLI.
  # ~/.claude/settings.json is reconciled from ./settings.nix on every switch.
  imports = [ ./settings.nix ];

  home.packages = [ pkgs.claude-code ];

  # Model is chosen via /model in Claude Code (persisted in settings) rather
  # than pinned here — an ANTHROPIC_MODEL env var would override that choice.

  # Enable experimental agent teams (parallel multi-agent orchestration)
  home.sessionVariables.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

  # Shell alias: `c` as shorthand for claude.
  # The `ct` / `claude-team` launcher (tmux -CC, iTerm2 control mode) is
  # macOS-only and lives in home/darwin/.
  programs.zsh.initContent = ''
    alias c='claude'
  '';

  # Claude Code manages its own binary at ~/.local/bin/claude via self-update.
  # The Nix package (home.packages) provides a fallback on PATH but we don't
  # fight the self-updater by symlinking over it.

  # Statusline script — displays workspace context and session info.
  # Wired into settings.json via the statusLine entry in ./settings.nix.
  home.file.".claude/statusline-command.sh" = {
    source = ../../files/claude/statusline-command.sh;
    executable = true;
  };
}
