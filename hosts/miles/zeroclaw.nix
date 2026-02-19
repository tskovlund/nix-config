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
      hash = "sha256-p8YJOzYL8aMeu7AaZEz3PWUJwh7epufKAHjJKetaGOU=";
    };

    cargoHash = "sha256-J7yAXEDFYL3banQNe/b8PzRpdRu67jU2W37nSf9Y7RY=";

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

  configFormat = pkgs.formats.toml { };
  configFile = configFormat.generate "zeroclaw-config.toml" {
    memory = {
      backend = "sqlite";
      auto_save = true;
      embedding_provider = "none";
      vector_weight = 0.0;
      keyword_weight = 1.0;
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

    environment = {
      HOME = "/var/lib/zeroclaw";
    };

    # Deploy Nix-managed config on every start. ZeroClaw-managed files
    # (auth-profiles.json, memory.db, .secret_key) are untouched.
    preStart = ''
      mkdir -p /var/lib/zeroclaw/.zeroclaw
      cp --remove-destination ${configFile} /var/lib/zeroclaw/.zeroclaw/config.toml
      chmod 644 /var/lib/zeroclaw/.zeroclaw/config.toml
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
