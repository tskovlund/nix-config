# ZeroClaw AI assistant — package, systemd service, and declarative configuration.
#
# Config.toml is generated from the Nix attrset below and deployed via the
# zeroclaw-setup oneshot service. Secrets (API key, Telegram token, gateway token)
# are agenix-encrypted in nix-config-personal and injected at deploy time.
#
# Eliza skills and workspace files are agenix-encrypted in eliza-config and
# decrypted by the NixOS agenix module to /var/lib/zeroclaw/.zeroclaw/workspace/.
#
# See docs/miles.md for operational runbook.
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

  # --- Declarative config.toml ---
  #
  # Secrets use placeholders (@ZEROCLAW_API_KEY@, etc.) that are replaced
  # with decrypted values by the zeroclaw-setup oneshot service at deploy time.
  zeroclaw-config = {
    api_key = "@ZEROCLAW_API_KEY@";
    default_provider = "openrouter";
    default_model = "anthropic/claude-sonnet-4.6";
    default_temperature = 0.7;

    model_routes = [
      {
        hint = "fast";
        provider = "openrouter";
        model = "anthropic/claude-haiku-4-5-20251001";
      }
      {
        hint = "default";
        provider = "openrouter";
        model = "anthropic/claude-sonnet-4.6";
      }
      {
        hint = "heavy";
        provider = "openrouter";
        model = "anthropic/claude-opus-4-20250514";
      }
    ];

    embedding_routes = [ ];

    observability = {
      backend = "prometheus";
      runtime_trace_mode = "none";
      runtime_trace_path = "state/runtime-trace.jsonl";
      runtime_trace_max_entries = 200;
    };

    autonomy = {
      level = "full";
      workspace_only = false;
      allowed_commands = [
        "git"
        "npm"
        "cargo"
        "ls"
        "cat"
        "grep"
        "find"
        "echo"
        "pwd"
        "wc"
        "head"
        "tail"
        "gh"
        "rm"
        "mkdir"
        "cp"
        "mv"
        "sed"
        "awk"
        "sort"
        "uniq"
        "diff"
        "tar"
        "jq"
        "python3"
        "date"
        "touch"
        "ln"
        "env"
        "xargs"
        "tr"
        "cut"
        "tac"
        "realpath"
        "dirname"
        "basename"
        "whoami"
        "id"
        "uname"
        "hostname"
        "which"
        "stat"
        "du"
        "df"
        "free"
        "uptime"
        "ps"
        "curl"
        "wget"
        "ssh"
        "scp"
        "pip"
        "npx"
        "node"
        "make"
        "nix"
        "systemctl"
        "journalctl"
        "unzip"
        "zip"
        "yq"
        "rg"
        "fd"
        "docker"
        "top"
        "htop"
        "vmstat"
        "iostat"
        "lsblk"
        "lsof"
        "ss"
        "ip"
        "dig"
        "nslookup"
        "ping"
        "file"
        "md5sum"
        "sha256sum"
        "base64"
        "less"
        "sleep"
        "test"
        "true"
        "false"
        "bc"
        "expr"
        "seq"
        "rsync"
        "pgrep"
        "pkill"
        "readlink"
        "getent"
        "nix-store"
        "nix-env"
        "nix-build"
        "nix-shell"
        "openssl"
        "age"
      ];
      forbidden_paths = [
        "/boot"
        "/sys"
        "~/.ssh"
        "~/.gnupg"
        "~/.aws"
      ];
      max_actions_per_hour = 500;
      max_cost_per_day_cents = 1000;
      require_approval_for_medium_risk = false;
      block_high_risk_commands = false;
      shell_env_passthrough = [ ];
      auto_approve = [
        "file_read"
        "file_write"
        "shell"
        "memory_store"
        "memory_recall"
        "memory_forget"
        "git_operations"
        "screenshot"
        "image_info"
        "cron_list"
        "cron_runs"
        "cron_add"
        "cron_remove"
        "cron_update"
        "cron_run"
        "schedule"
        "web_search_tool"
        "http_request"
        "delegate"
      ];
      always_ask = [ ];
      allowed_roots = [
        "/proc"
        "/etc"
        "/var/log"
        "/tmp"
        "/nix"
        "/run"
        "/var/lib/zeroclaw/repos"
      ];
      non_cli_excluded_tools = [ ];
    };

    security = {
      sandbox = {
        backend = "none";
        firejail_args = [ ];
      };
      resources = {
        max_memory_mb = 512;
        max_cpu_time_seconds = 60;
        max_subprocesses = 10;
        memory_monitoring = true;
      };
      audit = {
        enabled = true;
        log_path = "audit.log";
        max_size_mb = 100;
        sign_events = false;
      };
      otp = {
        enabled = false;
        method = "totp";
        token_ttl_secs = 30;
        cache_valid_secs = 300;
        gated_actions = [
          "shell"
          "file_write"
          "browser_open"
          "browser"
          "memory_forget"
        ];
        gated_domains = [ ];
        gated_domain_categories = [ ];
      };
      estop = {
        enabled = true;
        state_file = "~/.zeroclaw/estop-state.json";
        require_otp_to_resume = true;
      };
    };

    runtime = {
      kind = "native";
      docker = {
        image = "alpine:3.20";
        network = "none";
        memory_limit_mb = 512;
        cpu_limit = 1.0;
        read_only_rootfs = true;
        mount_workspace = true;
        allowed_workspace_roots = [ ];
      };
    };

    reliability = {
      provider_retries = 2;
      provider_backoff_ms = 500;
      fallback_providers = [ ];
      api_keys = [ ];
      channel_initial_backoff_secs = 2;
      channel_max_backoff_secs = 60;
      scheduler_poll_secs = 15;
      scheduler_retries = 2;
      model_fallbacks = { };
    };

    scheduler = {
      enabled = true;
      max_tasks = 64;
      max_concurrent = 4;
    };

    agent = {
      compact_context = false;
      max_tool_iterations = 200;
      max_history_messages = 30;
      parallel_tools = true;
      tool_dispatcher = "auto";
    };

    skills = {
      open_skills_enabled = false;
      prompt_injection_mode = "full";
    };

    query_classification = {
      enabled = true;
      rules = [
        {
          hint = "fast";
          priority = 10;
          max_length = 100;
          keywords = [
            "hi"
            "hello"
            "hey"
            "thanks"
            "ok"
            "yes"
            "no"
            "good morning"
            "gm"
            "weather"
            "time"
            "date"
          ];
        }
        {
          hint = "heavy";
          priority = 20;
          keywords = [
            "review"
            "architect"
            "design"
            "plan"
            "analyze"
            "debug"
            "refactor"
            "strategy"
            "mutation"
            "complex"
            "trade-off"
          ];
        }
        {
          hint = "heavy";
          priority = 15;
          min_length = 500;
        }
        {
          hint = "heavy";
          priority = 15;
          patterns = [
            "\`\`\`"
            "fn "
            "def "
            "class "
          ];
        }
      ];
    };

    heartbeat = {
      enabled = true;
      interval_minutes = 30;
    };

    cron = {
      enabled = true;
      max_run_history = 50;
    };

    channels_config = {
      cli = true;
      message_timeout_secs = 300;
      telegram = {
        bot_token = "@TELEGRAM_BOT_TOKEN@";
        allowed_users = [ "tskovlund" ];
        stream_mode = "off";
        draft_update_interval_ms = 1000;
        interrupt_on_new_message = false;
        mention_only = false;
      };
    };

    memory = {
      backend = "sqlite";
      auto_save = true;
      hygiene_enabled = true;
      archive_after_days = 2;
      purge_after_days = 30;
      conversation_retention_days = 30;
      embedding_provider = "none";
      embedding_model = "text-embedding-3-small";
      embedding_dimensions = 1536;
      vector_weight = 0.7;
      keyword_weight = 0.3;
      min_relevance_score = 0.4;
      embedding_cache_size = 10000;
      chunk_max_tokens = 512;
      response_cache_enabled = true;
      response_cache_ttl_minutes = 60;
      response_cache_max_entries = 5000;
      snapshot_enabled = true;
      snapshot_on_hygiene = true;
      auto_hydrate = true;
    };

    storage.provider.config = {
      provider = "";
      schema = "public";
      table = "memories";
    };

    tunnel.provider = "none";

    gateway = {
      port = 3000;
      host = "0.0.0.0";
      require_pairing = true;
      allow_public_bind = true;
      paired_tokens = [ "@GATEWAY_PAIRED_TOKEN@" ];
      pair_rate_limit_per_minute = 10;
      webhook_rate_limit_per_minute = 60;
      trust_forwarded_headers = false;
      rate_limit_max_keys = 10000;
      idempotency_ttl_secs = 300;
      idempotency_max_keys = 10000;
    };

    composio = {
      enabled = false;
      entity_id = "default";
    };

    # Disable ZeroClaw's native secret encryption — secrets are managed by agenix
    # and injected into config.toml at deploy time by the zeroclaw-setup service.
    secrets.encrypt = false;

    browser = {
      enabled = true;
      allowed_domains = [ ];
      backend = "agent_browser";
      native_headless = true;
      native_webdriver_url = "http://127.0.0.1:9515";
      computer_use = {
        endpoint = "http://127.0.0.1:8787/v1/actions";
        timeout_ms = 15000;
        allow_remote_endpoint = false;
        window_allowlist = [ ];
      };
    };

    http_request = {
      enabled = true;
      allowed_domains = [ "*" ];
      max_response_size = 0;
      timeout_secs = 30;
    };

    multimodal = {
      max_images = 4;
      max_image_size_mb = 5;
      allow_remote_fetch = true;
    };

    web_search = {
      enabled = true;
      provider = "duckduckgo";
      max_results = 5;
      timeout_secs = 15;
    };

    proxy = {
      enabled = false;
      no_proxy = [ ];
      scope = "zeroclaw";
      services = [ ];
    };

    identity.format = "openclaw";

    cost = {
      enabled = true;
      daily_limit_usd = 10.0;
      monthly_limit_usd = 100.0;
      warn_at_percent = 80;
      allow_override = false;
      prices = {
        "anthropic/claude-3.5-sonnet" = {
          input = 3.0;
          output = 15.0;
        };
        "openai/o1-preview" = {
          input = 15.0;
          output = 60.0;
        };
        "anthropic/claude-opus-4-20250514" = {
          input = 15.0;
          output = 75.0;
        };
        "anthropic/claude-sonnet-4-20250514" = {
          input = 3.0;
          output = 15.0;
        };
        "google/gemini-2.0-flash" = {
          input = 0.1;
          output = 0.4;
        };
        "anthropic/claude-3-haiku" = {
          input = 0.25;
          output = 1.25;
        };
        "google/gemini-1.5-pro" = {
          input = 1.25;
          output = 5.0;
        };
        "openai/gpt-4o-mini" = {
          input = 0.15;
          output = 0.6;
        };
        "openai/gpt-4o" = {
          input = 5.0;
          output = 15.0;
        };
      };
    };

    peripherals = {
      enabled = false;
      boards = [ ];
    };

    agents = { };

    hooks = {
      enabled = true;
      builtin.command_logger = false;
    };

    hardware = {
      enabled = false;
      transport = "None";
      baud_rate = 115200;
      workspace_datasheets = false;
    };

    transcription = {
      enabled = true;
      api_url = "https://openrouter.ai/api/v1/audio/transcriptions";
      model = "whisper-large-v3-turbo";
      max_duration_secs = 120;
    };
  };

  configFile = (pkgs.formats.toml { }).generate "zeroclaw-config.toml" zeroclaw-config;

in
{
  # System user — allows running CLI commands for setup:
  #   sudo -u zeroclaw zeroclaw status
  users.users.zeroclaw = {
    isSystemUser = true;
    group = "zeroclaw";
    home = "/var/lib/zeroclaw";
    extraGroups = [ "systemd-journal" ];
  };
  users.groups.zeroclaw = { };

  # --- Agenix secrets: Eliza skills and workspace files ---
  # Decrypted to /run/agenix/ (default location), then copied to the zeroclaw
  # workspace by zeroclaw-setup. We don't use custom `path` because agenix
  # activation runs before the workspace directories exist.
  age.secrets =
    let
      mkElizaSecret = name: {
        file = "${eliza-config}/secrets/${name}.age";
        mode = "0644";
      };
    in
    {
      eliza-skill-delegation = mkElizaSecret "skill-delegation";
      eliza-skill-docs = mkElizaSecret "skill-docs";
      eliza-skill-linear-operations = mkElizaSecret "skill-linear-operations";
      eliza-skill-memory-management = mkElizaSecret "skill-memory-management";
      eliza-skill-morning-briefing = mkElizaSecret "skill-morning-briefing";
      eliza-skill-notification-routing = mkElizaSecret "skill-notification-routing";
      eliza-skill-pr-review = mkElizaSecret "skill-pr-review";
      eliza-skill-self-improvement = mkElizaSecret "skill-self-improvement";
      eliza-skill-skill-management = mkElizaSecret "skill-skill-management";
      eliza-skill-system-health = mkElizaSecret "skill-system-health";

      eliza-workspace-AGENTS = mkElizaSecret "workspace-AGENTS";
      eliza-workspace-IDENTITY = mkElizaSecret "workspace-IDENTITY";
      eliza-workspace-SOUL = mkElizaSecret "workspace-SOUL";
      eliza-workspace-TOOLS = mkElizaSecret "workspace-TOOLS";
      eliza-workspace-USER = mkElizaSecret "workspace-USER";
    };

  # Deploy SSH keys, config.toml, and .gitconfig for ZeroClaw.
  # Runs as root before zeroclaw.service — accesses Thomas's home for agenix secrets.
  # Same pattern as restic-secrets in backups.nix.
  systemd.services.zeroclaw-setup = {
    description = "Deploy keys and config for ZeroClaw";
    wantedBy = [ "multi-user.target" ];
    after = [ "home-manager-thomas.service" ]; # agenix secrets must be decrypted first
    before = [ "zeroclaw.service" ];
    path = [ pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # --- SSH keys ---

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

      # --- Git identity ---
      # ZeroClaw's security policy blocks `git config` at runtime
      # (hardcoded in is_args_safe()), so we create .gitconfig here.
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
      chown zeroclaw:zeroclaw /var/lib/zeroclaw/.gitconfig

      # --- Age key (for self-modification: decrypt/encrypt skills) ---

      AGE_KEY_SRC="/home/${username}/.config/agenix/age-key.txt"
      AGE_KEY_DEST="/var/lib/zeroclaw/.config/agenix/age-key.txt"
      mkdir -p /var/lib/zeroclaw/.config/agenix
      if [ -f "$AGE_KEY_SRC" ]; then
        cp "$AGE_KEY_SRC" "$AGE_KEY_DEST"
        chown zeroclaw:zeroclaw /var/lib/zeroclaw/.config/agenix
        chown zeroclaw:zeroclaw "$AGE_KEY_DEST"
        chmod 600 "$AGE_KEY_DEST"
      else
        echo "WARNING: $AGE_KEY_SRC not found — self-modification encryption will fail"
      fi

      # --- Eliza skills and workspace files ---
      # Agenix decrypts to /run/agenix/eliza-*. Copy to the workspace.

      mkdir -p /var/lib/zeroclaw/.zeroclaw/workspace/skills

      for secret in /run/agenix/eliza-skill-*; do
        [ -f "$secret" ] || continue
        name=$(basename "$secret" | ${pkgs.gnused}/bin/sed 's/^eliza-skill-//')
        mkdir -p "/var/lib/zeroclaw/.zeroclaw/workspace/skills/$name"
        cp "$secret" "/var/lib/zeroclaw/.zeroclaw/workspace/skills/$name/SKILL.md"
      done

      for secret in /run/agenix/eliza-workspace-*; do
        [ -f "$secret" ] || continue
        name=$(basename "$secret" | ${pkgs.gnused}/bin/sed 's/^eliza-workspace-//')
        cp "$secret" "/var/lib/zeroclaw/.zeroclaw/workspace/$name.md"
      done

      chown -R zeroclaw:zeroclaw /var/lib/zeroclaw/.zeroclaw/workspace

      # --- Config.toml ---
      # Base config from Nix store with secret placeholders.
      # Secrets are injected from agenix-decrypted paths in Thomas's home.

      cp ${configFile} /var/lib/zeroclaw/.zeroclaw/config.toml

      API_KEY_FILE="/home/${username}/.config/zeroclaw/api-key"
      if [ -f "$API_KEY_FILE" ]; then
        API_KEY=$(cat "$API_KEY_FILE")
        ${pkgs.gnused}/bin/sed -i "s|@ZEROCLAW_API_KEY@|$API_KEY|g" /var/lib/zeroclaw/.zeroclaw/config.toml
      else
        echo "WARNING: $API_KEY_FILE not found — ZeroClaw API calls will fail"
      fi

      TELEGRAM_TOKEN_FILE="/home/${username}/.config/zeroclaw/telegram-bot-token"
      if [ -f "$TELEGRAM_TOKEN_FILE" ]; then
        TELEGRAM_TOKEN=$(cat "$TELEGRAM_TOKEN_FILE")
        ${pkgs.gnused}/bin/sed -i "s|@TELEGRAM_BOT_TOKEN@|$TELEGRAM_TOKEN|g" /var/lib/zeroclaw/.zeroclaw/config.toml
      else
        echo "WARNING: $TELEGRAM_TOKEN_FILE not found — Telegram channel will fail"
      fi

      GATEWAY_TOKEN_FILE="/home/${username}/.config/zeroclaw/gateway-token"
      if [ -f "$GATEWAY_TOKEN_FILE" ]; then
        GATEWAY_TOKEN=$(cat "$GATEWAY_TOKEN_FILE")
        ${pkgs.gnused}/bin/sed -i "s|@GATEWAY_PAIRED_TOKEN@|$GATEWAY_TOKEN|g" /var/lib/zeroclaw/.zeroclaw/config.toml
      else
        echo "WARNING: $GATEWAY_TOKEN_FILE not found — gateway pairing will fail"
      fi

      chown zeroclaw:zeroclaw /var/lib/zeroclaw/.zeroclaw/config.toml
      chmod 600 /var/lib/zeroclaw/.zeroclaw/config.toml
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
      pkgs.age # decrypt .age files
    ];
    script = ''
      set -euo pipefail
      CLONE="/var/lib/zeroclaw/repos/eliza-config"
      WORKSPACE="/var/lib/zeroclaw/.zeroclaw/workspace"
      AGE_KEY="/var/lib/zeroclaw/.config/agenix/age-key.txt"

      # Remove trigger first (so it can be re-created for next deploy)
      rm -f /var/lib/zeroclaw/.zeroclaw/redeploy-trigger

      # Pull latest from the local clone
      # - safe.directory: clone is owned by zeroclaw, this service runs as root
      # - GIT_SSH_COMMAND: use zeroclaw's SSH key (service runs as root)
      export GIT_SSH_COMMAND="ssh -i /var/lib/zeroclaw/.ssh/id_ed25519_github -o UserKnownHostsFile=/var/lib/zeroclaw/.ssh/known_hosts"
      git -c safe.directory='*' -C "$CLONE" fetch origin
      git -c safe.directory='*' -C "$CLONE" reset --hard origin/main

      # Hot reload: decrypt skills from .age files
      for agefile in "$CLONE"/secrets/skill-*.age; do
        [ -f "$agefile" ] || continue
        name=$(basename "$agefile" .age)
        skill_dir=$(echo "$name" | sed 's/^skill-//')
        mkdir -p "$WORKSPACE/skills/$skill_dir"
        age -d -i "$AGE_KEY" "$agefile" > "$WORKSPACE/skills/$skill_dir/SKILL.md"
      done

      # Hot reload: decrypt workspace files from .age files
      for agefile in "$CLONE"/secrets/workspace-*.age; do
        [ -f "$agefile" ] || continue
        name=$(basename "$agefile" .age)
        md_name=$(echo "$name" | sed 's/^workspace-//')
        age -d -i "$AGE_KEY" "$agefile" > "$WORKSPACE/$md_name.md"
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
      "zeroclaw-setup.service"
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
      age # decrypt/encrypt agenix secrets for self-modification
    ];

    environment = {
      HOME = "/var/lib/zeroclaw";
    };

    # Skills and workspace files are deployed by agenix (age.secrets above).
    # Workspace directories are created by tmpfiles rules.
    preStart = ''
      # Persistent clone of eliza-config for self-modification.
      # Eliza edits skills here, commits, pushes, then touches the redeploy trigger.
      # Non-fatal: SSH key may not be available on first deploy.
      if [ ! -d /var/lib/zeroclaw/repos/eliza-config/.git ]; then
        mkdir -p /var/lib/zeroclaw/repos
        ${pkgs.git}/bin/git clone git@github.com:tskovlund/eliza-config.git /var/lib/zeroclaw/repos/eliza-config || \
          echo "WARNING: git clone failed — self-modification unavailable until key is deployed"
      fi
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
