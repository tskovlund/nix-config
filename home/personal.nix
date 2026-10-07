{ pkgs, ... }:

{
  imports = [
  ];

  # Personal additions layered on top of the base dev environment.
  # Only imported by the "darwin" / "linux" targets, not "darwin-base" / "linux-base".
  #
  # Put personal aliases, fun tools, personal SSH hosts, etc. here.
  # If something would be useful on any dev machine, it belongs in default.nix instead.

  home.packages = with pkgs; [
    hcloud # Hetzner Cloud CLI
    flarectl # Cloudflare DNS management
  ];

  # Personal Notion and Linear workspaces, merged into ~/.claude/settings.json
  # by home/claude/settings.nix.
  claude.settings = {
    enabledPlugins = {
      "Notion@claude-plugins-official" = true;
      "linear@claude-plugins-official" = true;
    };
    permissions.allow = [
      "mcp__plugin_linear_linear__*"
      "mcp__plugin_Notion_notion__*"
    ];
  };

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
