# MCP Memory Service — shared semantic memory for Claude Code and Eliza.
#
# Runs mcp-memory-service in Streamable HTTP mode on port 8765.
# Accessible only via Tailscale (trustedInterfaces in tailscale.nix).
# API key authentication provides defense in depth.
#
# Consumers:
#   - Claude Code (macOS): claude mcp add --transport http -H "X-API-Key: <key>" memory http://miles:8765/mcp
#   - ZeroClaw/Eliza: HTTP requests to localhost:8765/mcp (via curl, no auth needed from localhost)
#
# Eliza integration:
#   ZeroClaw has built-in memory tools (memory_store/recall/forget) backed by brain.db.
#   These remain for conversation history. For long-term shared knowledge (decisions,
#   preferences, findings), Eliza uses the shared mcp-memory-service via HTTP requests.
#   This is configured in eliza-config's TOOLS.md workspace file.
#
# Post-deploy setup:
#   1. Generate API key: openssl rand -hex 32
#   2. Encrypt: agenix -e secrets/mcp-memory-api-key.age (in nix-config-personal)
#   3. Deploy: make switch (macOS) + make deploy-miles
#   4. Register in Claude Code:
#      claude mcp remove memory  # remove old stdio registration
#      claude mcp add --transport http --scope user \
#        -H "X-API-Key: $(cat ~/.config/mcp-memory/api-key)" \
#        memory http://miles:8765/mcp
{
  pkgs,
  username,
  ...
}:

let
  pythonEnv = pkgs.python312.withPackages (ps: [ pkgs.mcp-memory-service ]);
  dataDir = "/var/lib/mcp-memory";
in
{
  # System user for the memory service
  users.users.mcp-memory = {
    isSystemUser = true;
    group = "mcp-memory";
    home = dataDir;
  };
  users.groups.mcp-memory = { };

  # Copy API key from agenix-decrypted home path to service directory.
  # Same pattern as restic-secrets in backups.nix.
  systemd.services.mcp-memory-secrets = {
    description = "Copy MCP memory API key for memory service";
    wantedBy = [ "mcp-memory.service" ];
    before = [ "mcp-memory.service" ];
    after = [ "home-manager-${username}.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p ${dataDir}

      SRC="/home/${username}/.config/mcp-memory/api-key"
      DEST="${dataDir}/env"
      if [ -f "$SRC" ]; then
        printf 'MCP_API_KEY=%s\n' "$(cat "$SRC")" > "$DEST"
      else
        echo "WARNING: $SRC not found — memory service will run without API key auth"
        printf 'MCP_API_KEY=not-yet-configured\n' > "$DEST"
      fi
      chown mcp-memory:mcp-memory "$DEST"
      chmod 400 "$DEST"
    '';
  };

  # MCP Memory Service — Streamable HTTP mode
  systemd.services.mcp-memory = {
    description = "MCP Memory Service (semantic memory)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "mcp-memory-secrets.service"
    ];

    environment = {
      # Transport: Streamable HTTP mode (not stdio)
      MCP_STREAMABLE_HTTP_MODE = "1";
      MCP_SSE_HOST = "0.0.0.0";
      MCP_SSE_PORT = "8765";

      # Storage: override base dir so DB lives in the StateDirectory
      # (default would be ~/.local/share/mcp-memory/ under the service user's HOME)
      MCP_MEMORY_BASE_DIR = dataDir;
      STORAGE_BACKEND = "sqlite-vec";

      # Embeddings: local ONNX (MiniLM-L6-v2), zero API cost
      MCP_MEMORY_USE_ONNX = "1";

      # Disable sentence-transformers import (not packaged, ONNX is sufficient)
      TRANSFORMERS_OFFLINE = "1";
    };

    serviceConfig = {
      Type = "simple";
      User = "mcp-memory";
      Group = "mcp-memory";
      StateDirectory = "mcp-memory";
      WorkingDirectory = dataDir;

      ExecStart = "${pythonEnv}/bin/python -m mcp_memory_service.server";

      Restart = "on-failure";
      RestartSec = 10;

      # API key from secrets oneshot (KEY=VALUE format)
      EnvironmentFile = "${dataDir}/env";

      # Security hardening (same level as zeroclaw)
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;

      # Allow writing to state directory
      ReadWritePaths = [ dataDir ];
    };
  };
}
