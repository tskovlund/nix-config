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
  username,
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
    extraGroups = [ "systemd-journal" ];
  };
  users.groups.zeroclaw = { };

  # Copy SSH key from Thomas's home to zeroclaw's home for GitHub access.
  # The id_ed25519_github key is decrypted by agenix to Thomas's ~/.ssh/ on deploy.
  # Same pattern as restic-secrets in backups.nix.
  systemd.services.zeroclaw-ssh-setup = {
    description = "Deploy SSH key for ZeroClaw GitHub access";
    wantedBy = [ "multi-user.target" ];
    before = [ "zeroclaw.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/zeroclaw/.ssh
      chown zeroclaw:zeroclaw /var/lib/zeroclaw/.ssh
      chmod 700 /var/lib/zeroclaw/.ssh

      # SSH auth key (GitHub push access + commit signing)
      SRC="/home/${username}/.ssh/id_ed25519_github"
      DEST="/var/lib/zeroclaw/.ssh/id_ed25519_github"
      if [ -f "$SRC" ]; then
        cp "$SRC" "$DEST"
        chown zeroclaw:zeroclaw "$DEST"
        chmod 600 "$DEST"
        # Public key needed for SSH commit signing (gpg.format=ssh)
        ssh-keygen -y -f "$DEST" > "$DEST.pub"
        chown zeroclaw:zeroclaw "$DEST.pub"
        chmod 644 "$DEST.pub"
      else
        echo "WARNING: $SRC not found — git push will fail until key is deployed"
      fi

      # GitHub host keys (pinned, avoids TOFU prompts)
      ${pkgs.openssh}/bin/ssh-keyscan -t ed25519,rsa github.com > /var/lib/zeroclaw/.ssh/known_hosts 2>/dev/null
      chown zeroclaw:zeroclaw /var/lib/zeroclaw/.ssh/known_hosts
      chmod 644 /var/lib/zeroclaw/.ssh/known_hosts

      # SSH config — route GitHub through this key
      cat > /var/lib/zeroclaw/.ssh/config <<'SSHCONFIG'
      Host github.com
        IdentityFile /var/lib/zeroclaw/.ssh/id_ed25519_github
        IdentitiesOnly yes
      SSHCONFIG
      chown zeroclaw:zeroclaw /var/lib/zeroclaw/.ssh/config
      chmod 644 /var/lib/zeroclaw/.ssh/config
    '';
  };

  # Watch for redeploy trigger file — hot-reloads skills and workspace files
  # from the local eliza-config clone without a full nixos-rebuild.
  # Eliza triggers this by: touch /var/lib/zeroclaw/.zeroclaw/redeploy-trigger
  systemd.paths.eliza-redeploy = {
    description = "Watch for Eliza redeploy trigger";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathExists = "/var/lib/zeroclaw/.zeroclaw/redeploy-trigger";
      Unit = "eliza-redeploy.service";
    };
  };

  systemd.services.eliza-redeploy = {
    description = "Hot-reload Eliza config from local clone";
    serviceConfig = {
      Type = "oneshot";
    };
    path = [
      pkgs.git
      pkgs.openssh # git fetch needs ssh for SSH remotes
    ];
    script = ''
      set -euo pipefail
      CLONE="/var/lib/zeroclaw/repos/eliza-config"
      WORKSPACE="/var/lib/zeroclaw/.zeroclaw/workspace"

      # Remove trigger first (so it can be re-created for next deploy)
      rm -f /var/lib/zeroclaw/.zeroclaw/redeploy-trigger

      # Pull latest from the local clone
      # - safe.directory: clone is owned by zeroclaw, this service runs as root
      # - GIT_SSH_COMMAND: use zeroclaw's SSH key (service runs as root)
      export GIT_SSH_COMMAND="ssh -i /var/lib/zeroclaw/.ssh/id_ed25519_github -o UserKnownHostsFile=/var/lib/zeroclaw/.ssh/known_hosts"
      git -c safe.directory='*' -C "$CLONE" fetch origin
      git -c safe.directory='*' -C "$CLONE" reset --hard origin/main

      # Hot reload: copy skills (replacing Nix store symlinks with real files)
      rm -rf "$WORKSPACE/skills"
      cp -r "$CLONE/skills" "$WORKSPACE/skills"

      # Hot reload: copy workspace files
      for file in "$CLONE"/workspace/*.md; do
        filename=$(basename "$file")
        rm -f "$WORKSPACE/$filename"
        cp "$file" "$WORKSPACE/$filename"
      done

      # Fix ownership
      chown -R zeroclaw:zeroclaw "$WORKSPACE"

      # Restart ZeroClaw to pick up changes
      systemctl restart zeroclaw.service
    '';
  };

  systemd.services.zeroclaw = {
    description = "ZeroClaw AI Assistant";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "zeroclaw-ssh-setup.service"
    ];
    wants = [ "network-online.target" ];

    path = with pkgs; [
      # Core — ZeroClaw shell tool runs `sh -c` so needs a shell + basic utils
      bash
      coreutils
      findutils
      diffutils
      gnugrep
      gnused
      gawk
      gzip
      util-linux # lsblk, etc.

      # System monitoring
      procps # ps, free, top, vmstat, pgrep, pkill
      iproute2 # ip, ss
      dnsutils # dig, nslookup

      # Dev tools
      git
      gh
      curl
      wget
      jq
      yq-go
      ripgrep
      fd
      gnumake
      openssh
      unzip
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

      # Git identity — ZeroClaw's security policy blocks `git config` at runtime
      # (hardcoded in is_args_safe()), so we create .gitconfig in preStart instead.
      # Tracked upstream: https://github.com/zeroclaw-labs/zeroclaw/issues/1398
      cat > /var/lib/zeroclaw/.gitconfig <<'GITCONFIG'
      [user]
        name = Eliza
        email = thomas@skovlund.dev
        signingKey = /var/lib/zeroclaw/.ssh/id_ed25519_github.pub
      [gpg]
        format = ssh
      [commit]
        gpgSign = true
      GITCONFIG

      # Persistent clone of eliza-config for self-modification.
      # Eliza edits skills here, commits, pushes, then touches the redeploy trigger.
      # Non-fatal: SSH key may not be available on first deploy.
      if [ ! -d /var/lib/zeroclaw/repos/eliza-config/.git ]; then
        mkdir -p /var/lib/zeroclaw/repos
        ${pkgs.git}/bin/git clone git@github.com:tskovlund/eliza-config.git /var/lib/zeroclaw/repos/eliza-config || \
          echo "WARNING: git clone failed — self-modification unavailable until key is deployed"
      fi

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

      # Hardening — ProtectSystem + StateDirectory is the core boundary:
      # Eliza can only write to /var/lib/zeroclaw, everything else is read-only.
      # Other restrictions are kept where they don't impede agent work.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
      ProtectKernelModules = true;
      RestrictRealtime = true;
    };
  };

  # Make zeroclaw CLI available system-wide for manual setup commands
  environment.systemPackages = [ zeroclaw ];
}
