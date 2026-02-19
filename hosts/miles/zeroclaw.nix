# ZeroClaw AI assistant — package, systemd service, and configuration.
#
# Post-deploy setup (run once):
#   sudo -u zeroclaw zeroclaw onboard --api-key <openrouter-key> --provider openrouter
#   sudo -u zeroclaw zeroclaw channel bind-telegram <chat-id>
#
# See docs/miles.md for full onboarding instructions.
{ lib, pkgs, ... }:

let
  zeroclaw = pkgs.rustPlatform.buildRustPackage rec {
    pname = "zeroclaw";
    version = "0.1.0";

    src = pkgs.fetchFromGitHub {
      owner = "zeroclaw-labs";
      repo = "zeroclaw";
      rev = "v${version}";
      hash = lib.fakeHash; # TODO: update after first build attempt on x86_64-linux
    };

    cargoHash = lib.fakeHash; # TODO: update after first build attempt on x86_64-linux

    # Disable default "hardware" feature (USB/serial) — not needed on VPS
    buildNoDefaultFeatures = true;

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

  dataDir = "/var/lib/zeroclaw";

  configFormat = pkgs.formats.toml { };
  configFile = configFormat.generate "zeroclaw-config.toml" {
    memory = {
      backend = "sqlite";
      auto_save = true;
      embedding_provider = "none";
      vector_weight = 0.7;
      keyword_weight = 0.3;
    };
  };
in
{
  # System user — allows running CLI commands for setup:
  #   sudo -u zeroclaw zeroclaw onboard ...
  users.users.zeroclaw = {
    isSystemUser = true;
    group = "zeroclaw";
    home = dataDir;
    createHome = true;
  };
  users.groups.zeroclaw = { };

  systemd.services.zeroclaw = {
    description = "ZeroClaw AI Assistant";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      HOME = dataDir;
    };

    # Deploy Nix-managed config on every start. ZeroClaw-managed files
    # (auth-profiles.json, memory.db, .secret_key) are untouched.
    preStart = ''
      mkdir -p ${dataDir}/.zeroclaw
      cp --remove-destination ${configFile} ${dataDir}/.zeroclaw/config.toml
      chmod 644 ${dataDir}/.zeroclaw/config.toml
    '';

    serviceConfig = {
      ExecStart = "${zeroclaw}/bin/zeroclaw daemon";
      User = "zeroclaw";
      Group = "zeroclaw";
      WorkingDirectory = dataDir;

      # Restart on failure with backoff
      Restart = "on-failure";
      RestartSec = "10s";

      # Hardening
      ProtectSystem = "strict";
      ReadWritePaths = [ dataDir ];
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
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
