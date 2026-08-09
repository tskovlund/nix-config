# Restic backups to Backblaze B2.
#
# Backs up application state (SQLite databases, config, workspace files) to B2 daily.
# Uses sqlite3 .backup for crash-consistent snapshots of active databases.
# Sends push notifications via ntfy on success and failure.
#
# Post-deploy setup:
#   1. Create B2 bucket "miles-backups" (private, default encryption)
#   2. Create B2 application key scoped to that bucket
#   3. Encrypt credentials: agenix -e secrets/restic-b2-env.age (in nix-config-personal)
#   4. Encrypt repo password: agenix -e secrets/restic-password.age
#   5. Save restic password in password manager (required for restore)
#   6. Deploy: make deploy-miles REFRESH=1
#   7. Verify: systemctl start restic-backups-miles && journalctl -fu restic-backups-miles
#   8. Subscribe to the backups topic in the ntfy app (via Tailscale: http://miles:2586)
{
  pkgs,
  username,
  ...
}:

let
  # Staging directory for SQLite snapshots (created by prepare, cleaned by cleanup)
  snapshotDir = "/var/lib/restic/snapshots";

  # SQLite databases that need .backup for consistency.
  # Paths verified on miles 2026-02-20.
  # Uptime Kuma and ntfy use DynamicUser — data lives in /var/lib/private/.
  sqliteDatabases = [
    {
      src = "/var/lib/zeroclaw/.zeroclaw/workspace/memory/brain.db";
      dest = "${snapshotDir}/zeroclaw-brain.db";
    }
    {
      src = "/var/lib/zeroclaw/.zeroclaw/workspace/cron/jobs.db";
      dest = "${snapshotDir}/zeroclaw-jobs.db";
    }
    {
      src = "/var/lib/grafana/data/grafana.db";
      dest = "${snapshotDir}/grafana.db";
    }
    {
      src = "/var/lib/private/uptime-kuma/kuma.db";
      dest = "${snapshotDir}/kuma.db";
    }
    {
      src = "/var/lib/private/ntfy-sh/user.db";
      dest = "${snapshotDir}/ntfy-user.db";
    }
    {
      src = "/var/lib/private/ntfy-sh/cache-file.db";
      dest = "${snapshotDir}/ntfy-cache.db";
    }
  ];

  # Generate sqlite3 .backup commands for all databases
  sqliteBackupScript = builtins.concatStringsSep "\n" (
    map (db: ''
      if [ -f "${db.src}" ]; then
        echo "Snapshotting ${db.src}..."
        ${pkgs.sqlite}/bin/sqlite3 "${db.src}" ".backup '${db.dest}'"
      else
        echo "Skipping ${db.src} (does not exist)"
      fi
    '') sqliteDatabases
  );

  ntfyUrl = "http://localhost:2586/backups";
in
{
  # --- Secrets ---

  # Copy restic secrets from agenix-decrypted home path to service directory.
  # Same pattern as grafana-smtp-password in observability.nix.
  systemd.services.restic-secrets = {
    description = "Copy restic secrets for backup service";
    wantedBy = [ "restic-backups-miles.service" ];
    before = [ "restic-backups-miles.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/restic

      # B2 environment file
      SRC_ENV="/home/${username}/.config/restic/b2-env"
      DEST_ENV="/var/lib/restic/b2-env"
      if [ -f "$SRC_ENV" ]; then
        cp "$SRC_ENV" "$DEST_ENV"
      else
        echo "WARNING: $SRC_ENV not found — backup will fail until secrets are deployed"
        printf 'B2_ACCOUNT_ID=not-yet-configured\nB2_ACCOUNT_KEY=not-yet-configured\n' > "$DEST_ENV"
      fi
      chmod 400 "$DEST_ENV"

      # Repository password
      SRC_PASS="/home/${username}/.config/restic/password"
      DEST_PASS="/var/lib/restic/password"
      if [ -f "$SRC_PASS" ]; then
        cp "$SRC_PASS" "$DEST_PASS"
      else
        echo "WARNING: $SRC_PASS not found — backup will fail until secrets are deployed"
        printf 'not-yet-configured' > "$DEST_PASS"
      fi
      chmod 400 "$DEST_PASS"
    '';
  };

  # --- Ntfy auth ---

  # Create ntfy user for backup notifications.
  # Same pattern as grafana-ntfy-auth in observability.nix.
  systemd.services.backup-ntfy-auth = {
    description = "Create ntfy user for backup notifications";
    wantedBy = [ "multi-user.target" ];
    after = [ "ntfy-sh.service" ];
    path = [
      pkgs.ntfy-sh
      pkgs.openssl
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      PASSWORD_FILE="/var/lib/restic/ntfy_password"
      if [ ! -f "$PASSWORD_FILE" ]; then
        mkdir -p /var/lib/restic
        PASSWORD=$(openssl rand -hex 16)
        printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" \
          | ntfy user add backup-alerts 2>/dev/null || \
          printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" \
            | ntfy user change-pass backup-alerts 2>/dev/null || true
        ntfy access backup-alerts backups write-only 2>/dev/null || true
        printf '%s' "$PASSWORD" > "$PASSWORD_FILE"
        chmod 400 "$PASSWORD_FILE"
      fi
    '';
  };

  # --- Backup job ---

  services.restic.backups.miles = {
    initialize = true;
    repository = "b2:miles-backups";
    environmentFile = "/var/lib/restic/b2-env";
    passwordFile = "/var/lib/restic/password";

    paths = [
      # Application data directories (configs, workspace files, uploads).
      # Uptime Kuma and ntfy use DynamicUser — real data is in /var/lib/private/.
      "/var/lib/zeroclaw"
      "/var/lib/private/uptime-kuma"
      "/var/lib/grafana"
      "/var/lib/private/ntfy-sh"
      # SQLite snapshots (created by backupPrepareCommand)
      snapshotDir
    ];

    exclude = [
      # Ephemeral files
      "*.lock"
      "*.pid"
      "*.sock"

      # SQLite WAL/journal files (snapshots are self-contained)
      "*.db-wal"
      "*.db-shm"
      "*.db-journal"

      # Live SQLite databases (use crash-consistent snapshots instead)
      "/var/lib/zeroclaw/.zeroclaw/workspace/memory/brain.db"
      "/var/lib/zeroclaw/.zeroclaw/workspace/cron/jobs.db"
      "/var/lib/grafana/data/grafana.db"
      "/var/lib/private/uptime-kuma/kuma.db"
      "/var/lib/private/ntfy-sh/user.db"
      "/var/lib/private/ntfy-sh/cache-file.db"

      # Grafana ephemeral data (rebuilt on start)
      "/var/lib/grafana/data/plugins"
      "/var/lib/grafana/data/png"
      "/var/lib/grafana/data/csv"
      "/var/lib/grafana/data/pdf"
      "/var/lib/grafana/data/log"

      # ZeroClaw git clones (can be re-cloned from remote)
      "/var/lib/zeroclaw/open-skills"
      "/var/lib/zeroclaw/repos"
    ];

    # Create consistent SQLite snapshots before backup
    backupPrepareCommand = ''
      mkdir -p ${snapshotDir}
      ${sqliteBackupScript}
      echo "SQLite snapshots complete"
    '';

    # Clean up SQLite snapshots (runs on both success and failure via ExecStopPost)
    backupCleanupCommand = ''
      rm -rf ${snapshotDir}
    '';

    # Daily at 02:30 UTC — before the 03:00-05:00 auto-upgrade window
    timerConfig = {
      OnCalendar = "02:30";
      Persistent = true; # run immediately if missed (e.g. server was rebooting)
      RandomizedDelaySec = "15m";
    };

    # Retention policy
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  # --- Notifications ---

  # Success notification (triggered by OnSuccess)
  systemd.services.restic-backup-notify-success = {
    description = "Send ntfy notification on backup success";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.curl ];
    script = ''
      NTFY_PASS=$(cat /var/lib/restic/ntfy_password 2>/dev/null || echo "")
      if [ -n "$NTFY_PASS" ]; then
        curl \
          --fail --silent --show-error \
          --max-time 10 \
          --retry 3 \
          -u "backup-alerts:$NTFY_PASS" \
          -H "Title: Backup OK: miles" \
          -H "Priority: default" \
          -H "Tags: white_check_mark" \
          -d "Daily backup to B2 completed successfully." \
          ${ntfyUrl} || echo "WARNING: ntfy notification failed"
      fi
    '';
  };

  # Failure notification (triggered by OnFailure)
  systemd.services.restic-backup-notify-failure = {
    description = "Send ntfy notification on backup failure";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.curl ];
    script = ''
      NTFY_PASS=$(cat /var/lib/restic/ntfy_password 2>/dev/null || echo "")
      if [ -n "$NTFY_PASS" ]; then
        curl \
          --fail --silent --show-error \
          --max-time 10 \
          --retry 3 \
          -u "backup-alerts:$NTFY_PASS" \
          -H "Title: Backup FAILED: miles" \
          -H "Priority: high" \
          -H "Tags: x" \
          -d "Daily backup to B2 failed. Check: journalctl -u restic-backups-miles" \
          ${ntfyUrl} || echo "WARNING: ntfy notification failed"
      fi
    '';
  };

  # Wire notifications into the restic backup service
  systemd.services.restic-backups-miles = {
    unitConfig.OnSuccess = [ "restic-backup-notify-success.service" ];
    unitConfig.OnFailure = [ "restic-backup-notify-failure.service" ];
  };

  # Make restic CLI available for manual operations (snapshots, restore, check)
  environment.systemPackages = [ pkgs.restic ];
}
