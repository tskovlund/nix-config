{ pkgs, ... }:

{
  # Claude Code — AI coding assistant CLI.
  # Settings and plugins are managed manually (see docs/manual-setup.md).
  home.packages = [ pkgs.claude-code-bin ];

  # Default to Opus 4.6
  home.sessionVariables.ANTHROPIC_MODEL = "claude-opus-4-6";

  # Enable experimental agent teams (parallel multi-agent orchestration)
  home.sessionVariables.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

  # Wrap claude in tmux -CC (iTerm2 control mode) so agent team splits
  # render as native iTerm2 panes. If already inside tmux, just run directly.
  programs.zsh.initContent = ''
    claude() {
      if [ -n "$TMUX" ]; then
        command claude --teammate-mode tmux "$@"
      else
        tmux -CC new-session "command claude --teammate-mode tmux $*"
      fi
    }
  '';

  # Claude Code expects to find itself at ~/.local/bin/claude for self-update checks.
  # Nix puts the binary in the store, so we symlink it to the expected location.
  home.file.".local/bin/claude".source = "${pkgs.claude-code-bin}/bin/claude";

  # Statusline script — displays workspace context and session info.
  # To activate, add to ~/.claude/settings.json:
  #   "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
  home.file.".claude/statusline-command.sh" = {
    source = ../../files/claude/statusline-command.sh;
    executable = true;
  };
}
