# miles — Hetzner Cloud VPS

Operational runbook for the `miles` VPS (Miles Davis). See `hosts/miles/` for the NixOS config.

## Server specs

| Property | Value |
|----------|-------|
| Provider | Hetzner Cloud |
| Server type | CX33 (x86, shared) |
| Resources | 4 vCPU, 8GB RAM, 80GB NVMe |
| Location | Nuremberg (nbg1) |
| IP | 46.225.116.48 |
| OS | NixOS (deployed via nixos-anywhere + disko) |
| Cost | ~€6.24/month |

## Hetzner resources

- **Server:** `miles` (ID: 121311252)
- **Firewall:** `miles-fw` (ID: 10552211) — inbound TCP 80, 443 (SSH via Tailscale only)
- **SSH key:** `miles` (uploaded to Hetzner, corresponds to `id_ed25519_miles`)
- **Protection:** delete + rebuild protection enabled

## DNS (Cloudflare)

DNS for `skovlund.dev` is managed in Cloudflare. Subdomain convention:

- `service.skovlund.dev` — short URL, points to primary server (miles)
- `service.miles.skovlund.dev` — namespaced URL, explicitly routed to miles
- Future servers: `service.coltrane.skovlund.dev`, etc.

Use DNS-only mode (grey cloud) — no Cloudflare proxy. The proxy interferes with WebSockets and Matrix federation.

Records:

```
miles.skovlund.dev        A       46.225.116.48
*.miles.skovlund.dev      A       46.225.116.48
status.skovlund.dev       CNAME   miles.skovlund.dev
notify.skovlund.dev       — (Resend-managed, email sending only)
```

Removed: `uptime.skovlund.dev`, `ntfy.skovlund.dev`, `grafana.skovlund.dev` — these services are now Tailscale-only. DNS records can be deleted from Cloudflare.

Additional CNAMEs added as services come online (matrix, openclaw, etc.).

## Security layers

Defense in depth — two independent firewalls:

| Layer | Level | What it does |
|-------|-------|--------------|
| Hetzner Cloud Firewall (`miles-fw`) | Network/hypervisor | Drops traffic before it reaches the VM |
| NixOS firewall (`networking.firewall`) | OS (nftables) | Drops traffic inside the VM |

Both must allow a port for traffic to reach a service. Update both when adding services.

Additional hardening:

- **Tailscale:** SSH is Tailscale-only — port 22 is not open on the NixOS firewall. See [Tailscale](#tailscale) section.
- **SSH:** key-only auth, no root password, `PermitRootLogin = "prohibit-password"`
- **fail2ban:** 5 retries, 1h ban, exponential backoff on repeat offenders. Tailscale CGNAT range (100.64.0.0/10) whitelisted via ignoreIP
- **sysctl:** dmesg_restrict, kptr_restrict, ptrace_scope, rp_filter, tcp_syncookies, log_martians
- **No hardened kernel** — breaks unprivileged user namespaces needed for rootless containers

## Services

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Tailscale | UDP 41641 | — | Mesh VPN (WireGuard). SSH + internal services via tailnet |
| SSH | 22 (Tailscale only) | — | Remote access + deployment |
| Caddy | 80, 443, 2019 (localhost) | — | Reverse proxy, HTTPS, Prometheus metrics |
| Uptime Kuma | 3001 (0.0.0.0) | `status.skovlund.dev/status/rbb` (rbb only) | Service availability monitoring |
| Ntfy | 2586 (0.0.0.0) | — (Tailscale: `http://miles:2586`) | Push notifications |
| ZeroClaw | 3000 (0.0.0.0) | — (Tailscale: `http://miles:3000`) | AI assistant + web dashboard (Telegram, OpenRouter) |
| Prometheus | 9090 (localhost) | — | Metrics storage and scraping |
| Grafana | 3002 (0.0.0.0) | — (Tailscale: `http://miles:3002`) | Dashboards and alerting |
| Loki | 3100 (localhost) | — | Log aggregation |
| Promtail | 9080 (localhost) | — | Ships journal logs to Loki |
| Node exporter | 9100 (localhost) | — | System metrics (CPU, memory, disk) |

Most services are Tailscale-only. Only the rbb status page (`status.skovlund.dev/status/rbb`) is exposed to the internet. All other routes, including the admin UI, return 404.

## Automatic upgrades

The server auto-upgrades from `github:tskovlund/nix-config#miles` every **Wednesday at 04:00 UTC**. This is offset from the Monday flake.lock update PR to allow time for review and merge.

The auto-upgrade passes `--override-input personal github:tskovlund/nix-config-personal` so it builds with the real identity. Without this, the build would use the stub personal input from `flake.lock` (`username = "user"`), deleting the real user account. See: 2026-03-04 incident.

Reboots are allowed within the 03:00–05:00 UTC window (only if a kernel update requires it).

To disable temporarily: `ssh root@miles systemctl stop nixos-upgrade.timer`

## Garbage collection

Automatic nix GC runs weekly on all NixOS hosts (config: `hosts/nixos/default.nix`):

- **GC:** deletes store paths older than 7 days
- **Store optimization:** deduplicates identical files in the Nix store

This is critical on miles' 80GB disk. Without GC, store bloat from auto-upgrades can fill the disk in weeks.

## Deployment

```sh
# Regular updates (via Tailscale — default)
# Requires dev shell on macOS: nix develop --command make deploy-miles
make deploy-miles

# Emergency deployment via public IP (requires port 22 re-enabled in NixOS firewall)
make deploy-miles MILES_HOST=root@46.225.116.48

# First-time install (wipes disk, installs NixOS — uses public IP before Tailscale exists)
nix run github:nix-community/nixos-anywhere -- --flake .#miles -i ~/.ssh/id_ed25519_miles root@<ip>

# SSH access (personal SSH config maps `miles` to Tailscale IP + key)
ssh miles          # as thomas (full shell/tools)
ssh root@miles     # as root (admin tasks)
ssh miles-direct   # emergency: via public IP (only works if port 22 is re-enabled)
```

`deploy-miles` automatically updates the `eliza-config` flake input (commits and pushes the lock change) before building, so Eliza's pushed skill changes are always included.

## Tailscale

Mesh VPN (WireGuard-based) creating a private network between Thomas's devices.

- **Config:** `hosts/miles/tailscale.nix`
- **Tailscale IP:** `100.100.125.93`
- **Public IP:** `46.225.116.48` (still exists, but SSH port closed in NixOS firewall)
- **Auth:** GitHub OAuth (account: tskovlund)
- **Interface:** `tailscale0` (trusted — all ports accessible via Tailscale)

SSH and all internal services (Prometheus, Loki, Promtail, Grafana metrics endpoint, etc.) are only reachable via Tailscale. Public internet only reaches Caddy (ports 80/443).

### Emergency SSH access

If Tailscale is down and you need SSH access:

1. Open Hetzner web console (cloud.hetzner.com → miles → Console)
2. Add port 22 back to `networking.firewall.allowedTCPPorts` in `hosts/miles/default.nix`
3. `nixos-rebuild switch` from the console
4. SSH via public IP: `ssh miles-direct` or `make deploy-miles MILES_HOST=root@46.225.116.48`
5. Fix Tailscale, then remove port 22 again

The Hetzner Cloud Firewall (`miles-fw`) always allows TCP 22 — only the NixOS firewall blocks it.

### Post-deploy setup (first time only)

1. Create Tailscale account at https://login.tailscale.com (GitHub OAuth)
2. Deploy: `make deploy-miles` (via public IP initially)
3. SSH to miles: `tailscale up` — authenticate via browser link
4. Verify: `tailscale status` shows both devices
5. From MacBook: `ssh root@<tailscale-ip>` works
6. Remove port 22 from `allowedTCPPorts`, redeploy via Tailscale IP

## Disaster recovery

To rebuild from scratch:

1. Create new CX33 server in Hetzner Cloud (nbg1, any base image, add `miles` SSH key)
2. Update IP in `Makefile` (`MILES_HOST`) and `docs/miles.md`
3. Run nixos-anywhere: `nix run github:nix-community/nixos-anywhere -- --flake .#miles -i ~/.ssh/id_ed25519_miles root@<new-ip>`
4. Verify: `ssh -i ~/.ssh/id_ed25519_miles root@<new-ip>`
5. Update DNS records in Cloudflare
6. Update Hetzner firewall: `hcloud firewall apply-to-resource miles-fw --type server --server miles`
7. Authenticate Tailscale: `ssh root@<new-ip>` then `tailscale up`
8. Update Tailscale IP in `Makefile` (`MILES_HOST`), `nix-config-personal/home/miles.nix`, and `docs/miles.md`
9. Commit IP changes, push

All state is either in the nix-config repo (declarative), encrypted in nix-config-personal (secrets), or backed up to Backblaze B2 (application data). See the Backups section for restore instructions.

## ZeroClaw (AI assistant)

ZeroClaw is the primary LLM gateway — provider routing, memory, and channel integrations.

- **Version:** built from source (`zeroclaw-src` flake input)
- **Config:** `hosts/miles/zeroclaw.nix` (NixOS module + package from source)
- **Config repo:** `github:tskovlund/eliza-config` (public, agenix-encrypted non-flake input)
- **Skills:** 10 deployed, agenix-encrypted (morning-briefing, pr-review, self-improvement, skill-management, docs, linear-operations, system-health, memory-management, delegation, notification-routing)
- **Workspace files:** 5 deployed, agenix-encrypted (SOUL.md, IDENTITY.md, AGENTS.md, TOOLS.md, USER.md)
- **Data:** `/var/lib/zeroclaw/.zeroclaw/` (SQLite memory DB, auth profiles, config)
- **User:** `zeroclaw` system user
- **Dashboard:** `http://miles:3000` (Tailscale only, requires pairing code from service logs)
- **Memory:** max_history_messages=30, archive_after_days=2, purge_after_days=30
- **Self-modification:** ZeroClaw can decrypt, edit, re-encrypt, and push skill/workspace changes via age key

### Configuration

Config.toml is declared as a Nix attrset in `zeroclaw.nix` and generated at deploy time. Secrets (API key, Telegram bot token, gateway pairing token) are agenix-encrypted in nix-config-personal and injected by the `zeroclaw-setup` oneshot service.

To change config: edit the `zeroclaw-config` attrset in `zeroclaw.nix`, then `make deploy-miles`.

To update secrets: `agenix -e secrets/zeroclaw-<name>.age` in nix-config-personal, then `make switch` (macOS) + `make deploy-miles`.

### eliza-config (skills and workspace)

The `eliza-config` repo is public on GitHub. All sensitive content (skills, workspace markdown) is agenix-encrypted at rest as `.age` files in `secrets/`. Git history was squashed before making the repo public.

**Deployment chain:**
1. nix-config imports eliza-config as a non-flake input (`github:tskovlund/eliza-config`)
2. NixOS agenix module decrypts `.age` files to `/run/agenix/` at activation
3. `zeroclaw-setup` oneshot copies decrypted files to workspace directories
4. Age key is deployed to `/var/lib/zeroclaw/.config/agenix/age-key.txt` for self-modification

**Self-modification flow:** ZeroClaw has `age` in PATH and can decrypt `.age` files, edit them, re-encrypt with `age -r <pubkey>`, commit, push, and touch a redeploy trigger. The `eliza-redeploy` systemd path unit watches for the trigger and hot-reloads changes.

### Systemd sandbox

The systemd unit provides the security boundary. Eliza can only write to `/var/lib/zeroclaw` (`StateDirectory`). Key constraints kept: `ProtectSystem=strict`, `ProtectHome`, `NoNewPrivileges`, `ProtectKernelModules`. ZeroClaw's internal sandbox is disabled (`backend = "none"`) to avoid double-jailing.

Tools in PATH: git, gh, curl, wget, jq, yq-go, ripgrep, fd, nodejs, python3, age.

### Common operations

```sh
# Check service status
systemctl status zeroclaw

# View logs
journalctl -u zeroclaw -f

# Restart after config changes
systemctl restart zeroclaw

# Run diagnostics
sudo -u zeroclaw zeroclaw doctor
```

### Routing strategy

ZeroClaw is the default gateway for LLM interactions. Direct API only when there's a clear reason.

- **Through ZeroClaw:** Chat, research, website content, alerts, Cambr batch analysis
- **Direct API:** Cambr strategy evaluation (latency-sensitive), CI/CD tasks, Claude Code

## Notifications

| Channel | Service | Purpose |
|---------|---------|---------|
| Ntfy | `http://miles:2586` (Tailscale) | Push notifications to phone (iOS/Android app) |
| Resend | `notify.skovlund.dev` | Transactional email (SMTP-compatible, 100/day free) |

Both are configured as Uptime Kuma notification channels. Ntfy relays through ntfy.sh for APNs/FCM push delivery.

Grafana alerting uses both channels:
- **Ntfy** (`grafana-alerts` user, `alerts` topic) — primary, push to phone
- **Email** (`grafana@notify.skovlund.dev` via Resend SMTP) — secondary

## Monitoring

- **Hetzner Dashboard:** CPU, RAM, disk, network graphs (built-in, no setup needed)
- **Uptime Kuma:** service availability monitoring at `http://miles:3001` (Tailscale)
- **Public status page:** `status.skovlund.dev/status/rbb` (only this route is publicly exposed — admin UI is Tailscale-only)
- **Grafana:** dashboards and alerting at `http://miles:3002` (Tailscale, Prometheus + Loki datasources)

### Observability stack

Config: `hosts/miles/observability.nix`

| Component | Role | Port |
|-----------|------|------|
| Prometheus | Metrics storage, scrapes node exporter + Caddy every 15s (30d retention) | 9090 |
| Node exporter | Exposes system metrics (CPU, memory, disk, systemd units) | 9100 |
| Loki | Log aggregation (30d retention) | 3100 |
| Promtail | Ships systemd journal → Loki | 9080 |
| Grafana | Dashboards, alerting → Ntfy + email | 3002 |

All services listen on localhost or 0.0.0.0 (protected by firewall). Grafana, ntfy, and Uptime Kuma admin are Tailscale-only. Only the rbb status page is exposed via Caddy.

**Provisioned declaratively:**
- **Datasources:** Prometheus (`uid: prometheus`) + Loki (`uid: loki`)
- **Dashboard:** Node Exporter Full (ID 1860, fetched at build time)
- **Contact points:** Ntfy webhook (`grafana-alerts` user) + email (Resend SMTP)
- **Alert rules:** disk >80%/90%, memory >85%, CPU >90% (5m), systemd failures, scrape targets down
- **Notification policy:** all alerts → ntfy-and-email, grouped by alertname, 4h repeat

**Post-deploy setup:**

1. Open `http://miles:3002` (via Tailscale), set password for `thomas` admin account
3. Verify contact points: Alerting → Contact points → Test
4. Create service account (Editor role) for MCP integration (see below)
5. If SMTP email alerts don't work: secrets may not have been deployed before Grafana first started. Fix: `rm /var/lib/grafana/smtp_password && systemctl restart grafana-smtp-password grafana`

### MCP integration (mcp-grafana)

Claude Code connects to Grafana via the `mcp-grafana` MCP server, providing tools for querying Prometheus/Loki, searching dashboards, and managing alerts.

Setup:
1. In Grafana: Administration → Service accounts → Add service account (Editor role) → Generate token
2. Encrypt token: `agenix -e secrets/grafana-service-account-token.age` in nix-config-personal
3. Deploy: `make switch` (to install the wrapper + decrypt the token)
4. Register: `claude mcp add --transport stdio --scope user grafana -- ~/.local/bin/mcp-grafana`

## Backups

Config: `hosts/miles/backups.nix`

| Property | Value |
|----------|-------|
| Backend | Backblaze B2 (`miles-backups` bucket) |
| Tool | Restic (encrypted, deduplicated, incremental) |
| Schedule | Daily at 02:30 UTC (before auto-upgrade window) |
| Retention | 7 daily, 4 weekly, 6 monthly |
| Notifications | Ntfy (`backups` topic, `backup-alerts` user) |

### What's backed up

| Directory | Content | SQLite snapshot? |
|-----------|---------|-----------------|
| `/var/lib/zeroclaw/` | ZeroClaw workspace (memory, config, markdown files, cron) | Yes (`brain.db`, `jobs.db`) |
| `/var/lib/private/uptime-kuma/` | Uptime Kuma monitors, notifications, uploads | Yes (`kuma.db`) |
| `/var/lib/grafana/` | Grafana config (mostly declarative, but includes manual changes) | Yes (`grafana.db`) |
| `/var/lib/private/ntfy-sh/` | Ntfy user DB, cache | Yes (`user.db`, `cache-file.db`) |

**Not backed up** (declarative or transient): Prometheus data, Loki chunks, Caddy certs (auto-renewed), Nix store (reproducible from flake), ZeroClaw `open-skills/` git clone.

### SQLite safety

The backup uses `sqlite3 .backup` to create crash-consistent snapshots before restic runs.
Snapshots are staged in `/var/lib/restic/snapshots/` during the backup and cleaned up after.
Services are NOT stopped — `.backup` uses SQLite's online backup API which is safe on active databases.

### Common operations

```sh
# Manual backup
systemctl start restic-backups-miles

# Check backup status
systemctl status restic-backups-miles
journalctl -u restic-backups-miles --since today

# List snapshots (run as root for access to env/password files)
set -a; source /var/lib/restic/b2-env; set +a
restic -r b2:miles-backups --password-file /var/lib/restic/password snapshots

# Restore a specific snapshot
restic -r b2:miles-backups --password-file /var/lib/restic/password \
  restore latest --target /tmp/restore

# Check repository integrity
restic -r b2:miles-backups --password-file /var/lib/restic/password check

# View backup size
restic -r b2:miles-backups --password-file /var/lib/restic/password stats
```

### Post-deploy setup (first time only)

1. Create Backblaze B2 account at backblaze.com
2. Create bucket: `miles-backups` (private, default encryption, no lifecycle rules)
3. Create application key scoped to that bucket
4. In nix-config-personal: `agenix -e secrets/restic-b2-env.age` — add `B2_ACCOUNT_ID=...` and `B2_ACCOUNT_KEY=...`
5. In nix-config-personal: `agenix -e secrets/restic-password.age` — add output of `openssl rand -base64 32`
6. **Save the restic password in your password manager** — without it, backups cannot be restored
7. Deploy: `make deploy-miles REFRESH=1` (secrets decrypt to `~/.config/restic/b2-env` and `~/.config/restic/password` via agenix, then a oneshot copies them to `/var/lib/restic/`)
8. If agenix secrets aren't picked up: `sudo systemctl --user -M thomas@ restart agenix`, then `systemctl restart restic-secrets`
9. Verify: `systemctl start restic-backups-miles && journalctl -fu restic-backups-miles`
10. Subscribe to the `backups` topic in the ntfy app: `http://miles:2586/backups` (requires Tailscale on phone)

### Restore after disaster recovery

After rebuilding the server (see Disaster Recovery section):

```sh
# 1. Stop services that own the data
systemctl stop zeroclaw uptime-kuma grafana ntfy-sh

# 2. Restore from B2
source /var/lib/restic/b2-env
restic -r b2:miles-backups --password-file /var/lib/restic/password \
  restore latest --target /tmp/restore

# 3. Restore SQLite snapshots (crash-consistent copies)
cp /tmp/restore/var/lib/restic/snapshots/zeroclaw-brain.db /var/lib/zeroclaw/.zeroclaw/workspace/memory/brain.db
cp /tmp/restore/var/lib/restic/snapshots/zeroclaw-jobs.db /var/lib/zeroclaw/.zeroclaw/workspace/cron/jobs.db
cp /tmp/restore/var/lib/restic/snapshots/grafana.db /var/lib/grafana/data/grafana.db
cp /tmp/restore/var/lib/restic/snapshots/kuma.db /var/lib/private/uptime-kuma/kuma.db
cp /tmp/restore/var/lib/restic/snapshots/ntfy-user.db /var/lib/private/ntfy-sh/user.db
cp /tmp/restore/var/lib/restic/snapshots/ntfy-cache.db /var/lib/private/ntfy-sh/cache-file.db

# 4. Restore non-DB files (configs, workspace markdown, uploads)
cp -a /tmp/restore/var/lib/zeroclaw/.zeroclaw/ /var/lib/zeroclaw/.zeroclaw/
cp -a /tmp/restore/var/lib/private/uptime-kuma/ /var/lib/private/uptime-kuma/
cp -a /tmp/restore/var/lib/private/ntfy-sh/ /var/lib/private/ntfy-sh/

# 5. Fix ownership
chown -R zeroclaw:zeroclaw /var/lib/zeroclaw

# 6. Restart services
systemctl start zeroclaw uptime-kuma grafana ntfy-sh

# 7. Clean up
rm -rf /tmp/restore
```
