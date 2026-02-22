# ZeroClaw AI assistant — package, systemd service, and configuration.
#
# Post-deploy setup (run once):
#   sudo -u zeroclaw zeroclaw onboard --api-key <openrouter-key> --provider openrouter
#   sudo -u zeroclaw zeroclaw channel bind-telegram <chat-id>
#
# See docs/miles.md for full onboarding instructions.
{
  lib,
  pkgs,
  zeroclaw-src,
  eliza-config,
  ...
}:

let
  zeroclaw = pkgs.rustPlatform.buildRustPackage {
    pname = "zeroclaw";
    version = "0-unstable-${zeroclaw-src.shortRev or "unknown"}";

    src = zeroclaw-src;

    cargoLock.lockFile = zeroclaw-src + "/Cargo.lock";

    # Disable default "hardware" feature (USB/serial) — not needed on VPS
    buildNoDefaultFeatures = true;

    # Some tests require git and network access, unavailable in the Nix sandbox
    doCheck = false;

    nativeBuildInputs = with pkgs; [
      pkg-config
      perl # required by ring (rustls dependency)
      cmake # required by some native C dependencies
    ];

    # All key deps are pure Rust or bundled:
    #   rusqlite: bundled SQLite (compiled from C source)
    #   reqwest: rustls (no OpenSSL needed)
    #   matrix-sdk: vodozemac (pure Rust crypto)

    meta = {
      description = "Fast, small, and fully autonomous AI assistant infrastructure";
      homepage = "https://github.com/zeroclaw-labs/zeroclaw";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux;
    };
  };

in
{
  # System user — allows running CLI commands for setup:
  #   sudo -u zeroclaw zeroclaw onboard ...
  users.users.zeroclaw = {
    isSystemUser = true;
    group = "zeroclaw";
    home = "/var/lib/zeroclaw";
  };
  users.groups.zeroclaw = { };

  systemd.services.zeroclaw = {
    description = "ZeroClaw AI Assistant";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [
      git
      gh # GitHub CLI
      curl
      wget
      jq
      yq-go
      ripgrep
      fd
      nodejs
      python3
    ];

    environment = {
      HOME = "/var/lib/zeroclaw";
    };

    # Ensure workspace directory exists and deploy skills + workspace files from eliza-config.
    # Config is created by `zeroclaw onboard`.
    # Files are symlinked to the Nix store, making them genuinely immutable.
    # Eliza must edit in the eliza-config repo and redeploy to change skills.
    preStart = ''
      mkdir -p /var/lib/zeroclaw/.zeroclaw/workspace/skills

      # Clean up stale skill entries (both symlinks and leftover directories)
      find /var/lib/zeroclaw/.zeroclaw/workspace/skills/ -maxdepth 1 -mindepth 1 -exec rm -rf {} + 2>/dev/null || true

      # Symlink each skill directory from the Nix store (immutable)
      for skill in ${eliza-config}/skills/*/; do
        skill_name=$(basename "$skill")
        ln -sfn "$skill" "/var/lib/zeroclaw/.zeroclaw/workspace/skills/$skill_name"
      done

      # Symlink workspace identity files from the Nix store (immutable)
      for file in ${eliza-config}/workspace/*.md; do
        filename=$(basename "$file")
        ln -sfn "$file" "/var/lib/zeroclaw/.zeroclaw/workspace/$filename"
      done
    '';

    serviceConfig = {
      ExecStart = "${zeroclaw}/bin/zeroclaw daemon";
      User = "zeroclaw";
      Group = "zeroclaw";
      StateDirectory = "zeroclaw";
      WorkingDirectory = "/var/lib/zeroclaw";

      # Restart on failure with backoff
      Restart = "on-failure";
      RestartSec = "10s";

      # Hardening
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      RestrictSUIDSGID = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
    };
  };

  # Make zeroclaw CLI available system-wide for manual setup commands
  environment.systemPackages = [ zeroclaw ];
}
