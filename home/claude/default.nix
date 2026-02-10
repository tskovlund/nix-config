{ pkgs, ... }:

{
  # Claude Code — AI coding assistant CLI.
  # Settings and plugins are managed manually (see CLAUDE.md).
  home.packages = [ pkgs.claude-code-bin ];

  # Statusline script — displays workspace context and session info.
  # To activate, add to ~/.claude/settings.json:
  #   "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
  home.file.".claude/statusline-command.sh" = {
    source = ../../files/claude/statusline-command.sh;
    executable = true;
  };
}
