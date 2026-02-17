# Hetzner Cloud CX32 VPS — "miles" (Miles Davis)
#
# Naming convention: jazz legends (miles, monk, mingus, coltrane, ...)
# Hardware: x86, 4 vCPU, 8GB RAM, 80GB NVMe, Falkenstein (fsn1)
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

  # TODO: Replace with your id_ed25519_miles.pub before first deploy
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA... TODO"
  ];

  # QEMU guest agent — enables Hetzner console operations (shutdown, snapshots)
  services.qemuGuest.enable = true;

  # Firewall — SSH only (more ports added by TSK-20/21)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Emergency access tools (regular tooling comes from home-manager)
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
  ];
}
