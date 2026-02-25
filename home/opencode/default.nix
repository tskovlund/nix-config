{ pkgs, ... }:

{
  # OpenCode — AI coding agent for the terminal (open-source).
  # https://github.com/anomalyco/opencode
  home.packages = [ pkgs.opencode ];

  # Shell alias: `oc` as shorthand for opencode.
  programs.zsh.initContent = ''
    alias oc='opencode'
  '';

  # Pre-warm the filesystem page cache for OpenCode at login.
  # WSL2's virtio filesystem has high cold-read latency. Reading the binary
  # and data directory into cache before the user launches OpenCode eliminates
  # the 10-30s unresponsive window after a fresh boot.
  systemd.user.services.opencode-cache-warm = {
    Unit = {
      Description = "Pre-warm OpenCode filesystem cache";
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (
        pkgs.writeShellScript "opencode-cache-warm" ''
          # Read the opencode binary into page cache
          ${pkgs.coreutils}/bin/cat ${pkgs.opencode}/bin/.opencode-wrapped > /dev/null 2>&1

          # Read the SQLite database and config
          for f in \
            "$HOME/.local/share/opencode/opencode.db" \
            "$HOME/.local/share/opencode/opencode.db-wal" \
            "$HOME/.config/opencode/opencode.jsonc" \
            "$HOME/.cache/opencode/models.json"; do
            [ -f "$f" ] && ${pkgs.coreutils}/bin/cat "$f" > /dev/null 2>&1
          done

          # Read node_modules directories (bun/formatter dependencies)
          for d in \
            "$HOME/.config/opencode/node_modules" \
            "$HOME/.cache/opencode/node_modules"; do
            [ -d "$d" ] && ${pkgs.findutils}/bin/find "$d" -type f -exec ${pkgs.coreutils}/bin/cat {} + > /dev/null 2>&1
          done
        ''
      );
      Nice = 19;
      IOSchedulingClass = "idle";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
