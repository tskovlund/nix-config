# Hetzner Cloud CX33 VPS — "miles" (Miles Davis)
#
# Naming convention: jazz legends (miles, monk, mingus, coltrane, ...)
# Hardware: x86, 4 vCPU, 8GB RAM, 80GB NVMe, Nuremberg (nbg1)
#
# This module is NOT responsible for importing hosts/nixos/ — makeNixOS
# handles that automatically. See docs/architecture.md.
{ modulesPath, pkgs, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
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

  # SSH — key-only auth, root login for remote deployment
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root = {
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWW14jBLp6lT6fQPSZ8nX5rDJsc2MU/iGWbc7ts4jzv miles"
    ];
  };

  # fail2ban — ban IPs after repeated SSH auth failures
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment.enable = true; # exponential backoff on repeat offenders
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
  system.autoUpgrade = {
    enable = true;
    flake = "github:tskovlund/nix-config#miles";
    dates = "Wed *-*-* 04:00:00";
    allowReboot = true;
    rebootWindow = {
      lower = "03:00";
      upper = "05:00";
    };
  };

  # Caddy — reverse proxy with automatic HTTPS (Let's Encrypt)
  services.caddy = {
    enable = true;
    virtualHosts."uptime.skovlund.dev".extraConfig = ''
      reverse_proxy localhost:3001
    '';
    virtualHosts."uptime.miles.skovlund.dev".extraConfig = ''
      redir https://uptime.skovlund.dev{uri}
    '';
    virtualHosts."status.skovlund.dev".extraConfig = ''
      reverse_proxy localhost:3001
    '';
    virtualHosts."status.miles.skovlund.dev".extraConfig = ''
      redir https://status.skovlund.dev{uri}
    '';
    virtualHosts."ntfy.skovlund.dev".extraConfig = ''
      reverse_proxy localhost:2586
    '';
    virtualHosts."ntfy.miles.skovlund.dev".extraConfig = ''
      redir https://ntfy.skovlund.dev{uri}
    '';
  };

  # Uptime Kuma — self-hosted service availability monitoring
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
    };
  };

  # Ntfy — self-hosted push notifications
  # After deploy, create admin user: ssh root@miles "ntfy user add --role=admin admin"
  services.ntfy-sh = {
    enable = true;
    settings = {
      "base-url" = "https://ntfy.skovlund.dev";
      "behind-proxy" = true;
      "auth-default-access" = "deny-all";
    };
  };

  # QEMU guest agent — enables Hetzner console operations (shutdown, snapshots)
  services.qemuGuest.enable = true;

  # Firewall — SSH + HTTP/HTTPS (Caddy)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
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
