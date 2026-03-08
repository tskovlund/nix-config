{ pkgs, lib, ... }:

{
  # Claude Code — AI coding assistant CLI.
  # Settings and plugins are managed manually (see docs/manual-setup.md).
  home.packages = [ pkgs.claude-code-bin ];

  # Default to Opus 4.6
  home.sessionVariables.ANTHROPIC_MODEL = "claude-opus-4-6";

  # Enable experimental agent teams (parallel multi-agent orchestration)
  home.sessionVariables.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

  # Shell aliases for Claude Code:
  #   c  — shorthand for claude
  #   ct — "claude team": launches inside tmux -CC (iTerm2 control mode)
  #         so agent team splits render as native iTerm2 panes
  programs.zsh.initContent = ''
    alias c='claude'
    alias claude-team='ct'
    ct() {
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

  # MCP Memory Service — semantic memory with vector search for Claude Code.
  # Uses ONNX embeddings (MiniLM-L6-v2) + SQLite-vec for local semantic search.
  # Replaces the old JSONL-based knowledge graph with richer memory operations.
  # Binary is Nix-managed; MCP registration is a one-time manual step
  # (see docs/manual-setup.md).
  home.file.".local/bin/mcp-memory-service" =
    let
      pythonEnv = pkgs.python312.withPackages (ps: [ pkgs.mcp-memory-service ]);
    in
    {
      executable = true;
      text = ''
        #!/bin/sh
        export MCP_MEMORY_STORAGE_PATH="''${MCP_MEMORY_STORAGE_PATH:-$HOME/.local/share/claude-memory}"
        export MCP_MEMORY_MODEL_PATH="$HOME/.local/share/claude-memory/models"
        export STORAGE_BACKEND="sqlite-vec"
        export MCP_MEMORY_USE_ONNX="1"
        exec ${pythonEnv}/bin/python -m mcp_memory_service.server "$@"
      '';
    };

  # Ensure memory data and model directories exist.
  home.activation.createClaudeMemoryDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/share/claude-memory"
    run mkdir -p "$HOME/.local/share/claude-memory/models"
  '';

  # MCP Grafana Server — observability integration for Claude Code.
  # Connects to Grafana on miles VPS, providing tools for querying Prometheus/Loki,
  # managing dashboards and alerts. Service account token from agenix (nix-config-personal).
  # Registration: claude mcp add --transport stdio --scope user grafana -- ~/.local/bin/mcp-grafana
  home.file.".local/bin/mcp-grafana" = {
    executable = true;
    text = ''
      #!/bin/sh
      export GRAFANA_URL="http://miles:3002"
      TOKEN_FILE="$HOME/.config/grafana/service-account-token"
      if [ -f "$TOKEN_FILE" ]; then
        export GRAFANA_SERVICE_ACCOUNT_TOKEN="$(cat "$TOKEN_FILE")"
      fi
      exec ${pkgs.mcp-grafana}/bin/mcp-grafana \
        --disable-oncall \
        --disable-incident \
        --disable-sift \
        --disable-pyroscope \
        --disable-rendering \
        "$@"
    '';
  };
}
