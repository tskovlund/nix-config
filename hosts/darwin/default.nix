{ pkgs, ... }:

{
  # Determinate Nix manages the Nix daemon and settings (flakes, nix-command, etc.).
  # Disable nix-darwin's Nix management to avoid conflicts.
  # Trade-off: nix-darwin's `nix.*` options (like nix.settings) are unavailable.
  # Configure Nix settings via Determinate instead.
  nix.enable = false;

  # No system-level packages yet — everything goes through home-manager.
  environment.systemPackages = [ ];

  # Platform identifier for this host.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # State version for nix-darwin. Set once on first build, never change.
  # Changing this can trigger irreversible state migrations.
  system.stateVersion = 5;
}
