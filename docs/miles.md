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
| Caddy | 80, 443 | — | Reverse proxy, automatic HTTPS |
| Uptime Kuma | 3001 (localhost) | `uptime.skovlund.dev` | Service availability monitoring |

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

# SSH access
ssh -i ~/.ssh/id_ed25519_miles root@46.225.116.48
ssh -i ~/.ssh/id_ed25519_miles thomas@46.225.116.48
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

All state is either in the nix-config repo (declarative) or encrypted in nix-config-personal (secrets). Nothing on the server is irreplaceable.

## Monitoring

- **Hetzner Dashboard:** CPU, RAM, disk, network graphs (built-in, no setup needed)
- **Uptime Kuma:** service availability monitoring at `uptime.skovlund.dev`
- **Future:** Grafana Cloud / OpenTelemetry when multiple services warrant deeper observability
