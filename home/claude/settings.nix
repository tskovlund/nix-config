{
  config,
  lib,
  pkgs,
  ...
}:

# ~/.claude/settings.json, reconciled on every switch.
#
# Claude Code writes to this file itself ("always allow", /config, /model),
# so it cannot be a read-only symlink into the Nix store. Instead an
# activation step deep-merges the `settings` attrset below into whatever is
# on disk with jq:
#
#   - keys declared in `settings` are enforced (the Nix value wins)
#   - keys Claude Code added on its own are left alone (e.g. `model`)
#   - `permissions.allow` / `permissions.deny` are treated as sets: entries
#     the user added stay, missing declared entries are appended, and
#     entries listed in `retired` are removed
#
# The file stays a plain writable JSON file. Nothing happens when the merge
# result equals the current content, and an unparseable file is left
# untouched with a warning rather than clobbered.
let
  settings = {
    enabledPlugins = {
      "Notion@claude-plugins-official" = true;
      "linear@claude-plugins-official" = true;
    };

    # Statusline script deployed by home/claude/default.nix
    statusLine = {
      type = "command";
      command = "bash ~/.claude/statusline-command.sh";
    };

    permissions = {
      defaultMode = "acceptEdits";
      allow = [
        "Bash(nix *)"
        "Bash(make *)"
        "Bash(home-manager *)"
        "Bash(darwin-rebuild *)"
        "Bash(nixos-rebuild *)"
        "Bash(git *)"
        "Bash(gh *)"
        "Bash(ls *)"
        "Bash(which *)"
        "Bash(* --version)"
        "Bash(* --help)"
        "Read"
        "mcp__plugin_linear_linear__*"
        "mcp__plugin_Notion_notion__*"
      ];
      deny = [
        "Bash(curl *)"
        "Bash(wget *)"
        "Read(./.env)"
        "Read(./.env.*)"
        "Read(~/.aws/**)"
        "Read(~/.ssh/id_*)"
      ];
    };

    # No automatic "Co-Authored-By" trailer or "Generated with Claude Code"
    # line: attribution is added deliberately per commit/PR when wanted.
    attribution = {
      commit = "";
      pr = "";
    };

    tui = "fullscreen";
    skipDangerousModePermissionPrompt = true;
    agentPushNotifEnabled = true;
  };

  # Previously managed entries that must be removed from existing files.
  # Keep entries here for a while after retiring them so every machine picks
  # up the removal on its next switch.
  retired = {
    permissions = {
      allow = [
        "mcp__memory__*" # memory MCP server removed in fe06dbb
      ];
      deny = [ ];
    };
  };

  settingsJson = pkgs.writeText "claude-settings-base.json" (builtins.toJSON settings);
  retiredJson = pkgs.writeText "claude-settings-retired.json" (builtins.toJSON retired);

  mergeProgram = pkgs.writeText "claude-settings-merge.jq" ''
    def reconcile($current; $wanted; $drop):
      (($current // []) + (($wanted // []) - ($current // []))) - ($drop // []);

    . as $current
    | ($current * $base)
    | .permissions.allow = reconcile($current.permissions.allow; $base.permissions.allow; $retired.permissions.allow)
    | .permissions.deny = reconcile($current.permissions.deny; $base.permissions.deny; $retired.permissions.deny)
  '';

  # Standalone script so the merge can be inspected or rerun by hand.
  reconcileScript = pkgs.writeShellScript "claude-settings-reconcile" ''
    set -euo pipefail
    jq=${pkgs.jq}/bin/jq
    settings="$1"

    current='{}'
    if [ -s "$settings" ]; then
      current=$(cat "$settings")
    fi

    if ! printf '%s' "$current" | "$jq" -e . >/dev/null 2>&1; then
      echo "claude-settings: $settings is not valid JSON, leaving it untouched" >&2
      exit 0
    fi

    merged=$(printf '%s' "$current" | "$jq" \
      --argjson base "$(cat ${settingsJson})" \
      --argjson retired "$(cat ${retiredJson})" \
      --from-file ${mergeProgram})

    # Compare normalised so key order and whitespace alone never trigger a write.
    if [ "$(printf '%s' "$current" | "$jq" -cS .)" = "$(printf '%s' "$merged" | "$jq" -cS .)" ]; then
      exit 0
    fi

    tmp=$(mktemp "$(dirname "$settings")/.settings.json.XXXXXX")
    printf '%s\n' "$merged" > "$tmp"
    # cp (not mv) keeps the existing file's mode and inode; the file is small.
    cp "$tmp" "$settings"
    rm -f "$tmp"
    echo "claude-settings: reconciled $settings"
  '';
in
{
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/.claude"
    run ${reconcileScript} "${config.home.homeDirectory}/.claude/settings.json"
  '';
}
