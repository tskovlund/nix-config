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
}
