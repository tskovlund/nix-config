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
- **Firewall:** `miles-fw` (ID: 10552211) — inbound TCP 22, 80, 443
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
uptime.skovlund.dev       CNAME   miles.skovlund.dev
status.skovlund.dev       CNAME   miles.skovlund.dev
ntfy.skovlund.dev         CNAME   miles.skovlund.dev
grafana.skovlund.dev      CNAME   miles.skovlund.dev
notify.skovlund.dev       — (Resend-managed, email sending only)
```

Additional CNAMEs added as services come online (matrix, openclaw, etc.).

## Security layers

Defense in depth — two independent firewalls:

| Layer | Level | What it does |
|-------|-------|--------------|
| Hetzner Cloud Firewall (`miles-fw`) | Network/hypervisor | Drops traffic before it reaches the VM |
| NixOS firewall (`networking.firewall`) | OS (nftables) | Drops traffic inside the VM |

Both must allow a port for traffic to reach a service. Update both when adding services.

Additional hardening:

- **SSH:** key-only auth, no root password, `PermitRootLogin = "prohibit-password"`
- **fail2ban:** 5 retries, 1h ban, exponential backoff on repeat offenders
- **sysctl:** dmesg_restrict, kptr_restrict, ptrace_scope, rp_filter, tcp_syncookies, log_martians
- **No hardened kernel** — breaks unprivileged user namespaces needed for rootless containers

## Services

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| SSH | 22 | — | Remote access + deployment |
| Caddy | 80, 443, 2019 (localhost) | — | Reverse proxy, HTTPS, Prometheus metrics |
| Uptime Kuma | 3001 (localhost) | `uptime.skovlund.dev` | Service availability monitoring |
| Uptime Kuma (status) | 3001 (localhost) | `status.skovlund.dev` | Public status pages |
| Ntfy | 2586 (localhost) | `ntfy.skovlund.dev` | Push notifications |
| ZeroClaw | — (daemon) | — | AI assistant (Telegram, OpenRouter) |
| Prometheus | 9090 (localhost) | — | Metrics storage and scraping |
| Grafana | 3002 (localhost) | `grafana.skovlund.dev` | Dashboards and alerting |
| Loki | 3100 (localhost) | — | Log aggregation |
| Promtail | 9080 (localhost) | — | Ships journal logs to Loki |
| Node exporter | 9100 (localhost) | — | System metrics (CPU, memory, disk) |

Namespaced URLs (`*.miles.skovlund.dev`) redirect to the canonical short URL.

## Automatic upgrades

The server auto-upgrades from `github:tskovlund/nix-config#miles` every **Wednesday at 04:00 UTC**. This is offset from the Monday flake.lock update PR to allow time for review and merge.

Reboots are allowed within the 03:00–05:00 UTC window (only if a kernel update requires it).

To disable temporarily: `ssh root@46.225.116.48 systemctl stop nixos-upgrade.timer`

## Deployment

```sh
# Regular updates (from macOS or any machine with the repo)
make deploy-miles

# First-time install (wipes disk, installs NixOS)
nix run github:nix-community/nixos-anywhere -- --flake .#miles -i ~/.ssh/id_ed25519_miles root@<ip>

# SSH access (personal SSH config maps `miles` to the IP + key)
ssh miles          # as thomas (full shell/tools)
ssh root@miles     # as root (admin tasks)
```

## Disaster recovery

To rebuild from scratch:

1. Create new CX33 server in Hetzner Cloud (nbg1, any base image, add `miles` SSH key)
2. Update IP in `Makefile` (`MILES_HOST`) and `docs/miles.md`
3. Run nixos-anywhere: `nix run github:nix-community/nixos-anywhere -- --flake .#miles -i ~/.ssh/id_ed25519_miles root@<new-ip>`
4. Verify: `ssh -i ~/.ssh/id_ed25519_miles root@<new-ip>`
5. Update DNS records in Cloudflare
6. Update Hetzner firewall: `hcloud firewall apply-to-resource miles-fw --type server --server miles`
7. Commit IP changes, push

All state is either in the nix-config repo (declarative), encrypted in nix-config-personal (secrets), or backed up to Backblaze B2 (application data). See the Backups section for restore instructions.

## ZeroClaw (AI assistant)

ZeroClaw is the primary LLM gateway — provider routing, memory, and channel integrations.

- **Config:** `hosts/miles/zeroclaw.nix` (NixOS module + package from source)
- **Data:** `/var/lib/zeroclaw/.zeroclaw/` (SQLite memory DB, auth profiles, config)
- **User:** `zeroclaw` system user

### First-time setup (after deploy)

```sh
# 1. Set up OpenRouter provider
sudo -u zeroclaw zeroclaw onboard --api-key <openrouter-api-key> --provider openrouter

# 2. Create a Telegram bot via @BotFather, get the token, then:
sudo -u zeroclaw zeroclaw channel bind-telegram <telegram-chat-id>

# 3. Verify
sudo -u zeroclaw zeroclaw status
sudo -u zeroclaw zeroclaw auth status
sudo -u zeroclaw zeroclaw channel doctor
```

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
| Ntfy | `ntfy.skovlund.dev` | Push notifications to phone (iOS/Android app) |
| Resend | `notify.skovlund.dev` | Transactional email (SMTP-compatible, 100/day free) |

Both are configured as Uptime Kuma notification channels. Ntfy relays through ntfy.sh for APNs/FCM push delivery.

Grafana alerting uses both channels:
- **Ntfy** (`grafana-alerts` user, `alerts` topic) — primary, push to phone
- **Email** (`grafana@notify.skovlund.dev` via Resend SMTP) — secondary

## Monitoring

- **Hetzner Dashboard:** CPU, RAM, disk, network graphs (built-in, no setup needed)
- **Uptime Kuma:** service availability monitoring at `uptime.skovlund.dev`
- **Status pages:** `status.skovlund.dev/status/all`, `status.skovlund.dev/status/rbb`
- **Grafana:** dashboards and alerting at `grafana.skovlund.dev` (Prometheus + Loki datasources)

### Observability stack

Config: `hosts/miles/observability.nix`

| Component | Role | Port |
|-----------|------|------|
| Prometheus | Metrics storage, scrapes node exporter + Caddy every 15s | 9090 |
| Node exporter | Exposes system metrics (CPU, memory, disk, systemd units) | 9100 |
| Loki | Log aggregation (30d retention) | 3100 |
| Promtail | Ships systemd journal → Loki | 9080 |
| Grafana | Dashboards, alerting → Ntfy + email | 3002 |

All services listen on localhost. Grafana is the only service exposed externally (via Caddy).

**Provisioned declaratively:**
- **Datasources:** Prometheus (`uid: prometheus`) + Loki (`uid: loki`)
- **Dashboard:** Node Exporter Full (ID 1860, fetched at build time)
- **Contact points:** Ntfy webhook (`grafana-alerts` user) + email (Resend SMTP)
- **Alert rules:** disk >80%/90%, memory >85%, CPU >90% (5m), systemd failures, scrape targets down
- **Notification policy:** all alerts → ntfy-and-email, grouped by alertname, 4h repeat

**Post-deploy setup:**

1. Add Cloudflare DNS: `grafana.skovlund.dev` CNAME → `miles.skovlund.dev`
2. Open `grafana.skovlund.dev`, set password for `thomas` admin account
3. Verify contact points: Alerting → Contact points → Test
4. Create service account (Editor role) for MCP integration (see below)

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
source /var/lib/restic/b2-env
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
7. Deploy: `make deploy-miles REFRESH=1`
8. Verify: `systemctl start restic-backups-miles && journalctl -fu restic-backups-miles`
9. Subscribe to the `backups` topic in the ntfy app: `ntfy.skovlund.dev/backups`

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
