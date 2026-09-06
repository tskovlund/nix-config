# Hetzner Cloud CX33 VPS — "miles" (Miles Davis)
#
# Naming convention: jazz legends (miles, monk, mingus, coltrane, ...)
# Hardware: x86, 4 vCPU, 8GB RAM, 80GB NVMe, Nuremberg (nbg1)
#
# This module is NOT responsible for importing hosts/nixos/ — makeNixOS
# handles that automatically. See docs/architecture.md.
{
  modulesPath,
  pkgs,
  username,
  ...
}:

let
  milesKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWW14jBLp6lT6fQPSZ8nX5rDJsc2MU/iGWbc7ts4jzv miles";
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./observability.nix
    ./backups.nix
    ./tailscale.nix
  ];

  # Boot — GRUB with BIOS boot (Hetzner Cloud x86 VPS)
  # GRUB device is set automatically by disko's EF02 (BIOS boot) partition
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  # Network — Hetzner assigns IPs via DHCP
  networking.useDHCP = true;

  # SSH — key-only auth, root login for remote deployment.
  # openFirewall = false: SSH is Tailscale-only. Port 22 is NOT opened
  # on the public interface. See tailscale.nix for access model.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [ milesKey ];
  users.users.${username}.openssh.authorizedKeys.keys = [ milesKey ];

  # Sudo — passwordless for wheel. The security boundary is SSH key auth,
  # not a Unix password (which isn't even set for the thomas account).
  security.sudo.wheelNeedsPassword = false;

  # fail2ban — ban IPs after repeated SSH auth failures
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment.enable = true; # exponential backoff on repeat offenders
    ignoreIP = [
      "100.64.0.0/10" # Tailscale CGNAT range — never ban our own devices
    ];
  };

  # Kernel hardening — targeted sysctl settings that don't break containers.
  # (The full hardened kernel disables unprivileged user namespaces, which
  # breaks rootless Podman/Docker. These sysctls give most of the benefit
  # without that trade-off.)
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1; # restrict dmesg to root
    "kernel.kptr_restrict" = 2; # hide kernel pointers from all users
    "kernel.yama.ptrace_scope" = 1; # restrict ptrace to parent processes
    "net.ipv4.conf.all.rp_filter" = 1; # reverse path filtering (anti-spoofing)
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.tcp_syncookies" = 1; # SYN flood protection
    "net.ipv4.conf.all.log_martians" = 1; # log spoofed/misrouted packets
  };

  # Automatic upgrades — rebuilds from the flake weekly on Wednesday 04:00 UTC.
  # Offset from the Monday flake.lock update PR to give time for review + merge.
  #
  # The --override-input is critical: without it, the build uses the stub
  # personal input (username = "user") from flake.lock, which deletes the
  # real user account and breaks SSH + backups. See: 2026-03-04 incident.
  system.autoUpgrade = {
    enable = true;
    flake = "github:tskovlund/nix-config#miles";
    flags = [
      "--override-input"
      "personal"
      "github:tskovlund/nix-config-personal"
    ];
    dates = "Wed *-*-* 04:00:00";
    allowReboot = true;
    rebootWindow = {
      lower = "03:00";
      upper = "05:00";
    };
  };

  # Caddy — reverse proxy with automatic HTTPS (Let's Encrypt)
  #
  # Only the rbb status page is publicly exposed. All other services (Grafana,
  # ntfy, Uptime Kuma admin) are Tailscale-only — accessed directly by port
  # via the trusted tailscale0 interface.
  services.caddy = {
    enable = true;
    globalConfig = ''
      servers {
        metrics
      }
    '';
    # Only the "rbb" status page is public. All other status pages, the admin UI,
    # login, and all other routes return 404.
    virtualHosts."status.skovlund.dev".extraConfig = ''
      @public {
        path /status/rbb
        path /status/rbb/
        path /status/rbb/*
        path /api/status-page/*
        path /assets/*
        path /icon.svg
        path /upload/*
        path /socket.io/*
        path /manifest.json
      }
      handle @public {
        reverse_proxy localhost:3001
      }
      handle {
        respond "Not Found" 404
      }
    '';
  };

  # Uptime Kuma — self-hosted service availability monitoring
  # Admin UI is Tailscale-only (http://miles:3001). Only the rbb status page
  # is served publicly via Caddy at status.skovlund.dev/status/rbb.
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
      HOST = "0.0.0.0"; # accessible via Tailscale (firewall blocks public access)
    };
  };

  # Ntfy — self-hosted push notifications (Tailscale-only)
  # After deploy, create admin user: ssh root@miles "ntfy user add --role=admin admin"
  services.ntfy-sh = {
    enable = true;
    settings = {
      "listen-http" = ":2586";
      "base-url" = "http://miles:2586";
      "auth-default-access" = "deny-all";
      "auth-file" = "/var/lib/ntfy-sh/user.db";
      "enable-login" = true;
      "upstream-base-url" = "https://ntfy.sh"; # relay to ntfy.sh for iOS/Android push via APNs/FCM
    };
  };

  # QEMU guest agent — enables Hetzner console operations (shutdown, snapshots)
  services.qemuGuest.enable = true;

  # Firewall — HTTP/HTTPS only (Caddy). SSH is Tailscale-only.
  # Emergency access: Hetzner Cloud Firewall still allows TCP 22. To restore
  # public SSH, add 22 back here and deploy via Hetzner web console.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
  };

  # Emergency access tools (regular tooling comes from home-manager)
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
  ];
}
