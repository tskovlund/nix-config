{ pkgs, lib, ... }:

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
  # Non-interactive subcommands (mcp, config, etc.) skip the tmux wrapper.
  programs.zsh.initContent = ''
    claude() {
      case "''${1:-}" in
        mcp|config|update|api-key|doctor)
          command claude "$@"
          return
          ;;
      esac
      if [ -n "$TMUX" ]; then
        command claude --teammate-mode tmux "$@"
      else
        tmux -CC new-session "command claude --teammate-mode tmux $*"
      fi
    }
  '';

  # Claude Code manages its own binary at ~/.local/bin/claude via self-update.
  # The Nix package (home.packages) provides a fallback on PATH but we don't
  # fight the self-updater by symlinking over it.

  # Statusline script — displays workspace context and session info.
  # To activate, add to ~/.claude/settings.json:
  #   "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
  home.file.".claude/statusline-command.sh" = {
    source = ../../files/claude/statusline-command.sh;
    executable = true;
  };

  # MCP Memory Server — persistent knowledge graph for Claude Code.
  # Stores entities, relations, and observations in a JSONL file.
  # Binary is Nix-managed; MCP registration is a one-time manual step
  # (see docs/manual-setup.md).
  home.file.".local/bin/mcp-server-memory" = {
    executable = true;
    text = ''
      #!/bin/sh
      export MEMORY_FILE_PATH="''${MEMORY_FILE_PATH:-$HOME/.local/share/claude-memory/memory.jsonl}"
      exec ${pkgs.mcp-server-memory}/bin/mcp-server-memory "$@"
    '';
  };

  # Ensure memory data directory exists.
  home.activation.createClaudeMemoryDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/share/claude-memory"
  '';
}
