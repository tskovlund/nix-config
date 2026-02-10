{ pkgs, ... }:

{
  # Determinate Nix manages the Nix daemon and settings (flakes, nix-command, etc.).
  # Disable nix-darwin's Nix management to avoid conflicts.
  # Trade-off: nix-darwin's `nix.*` options (like nix.settings) are unavailable.
  # Configure Nix settings via Determinate instead.
  nix.enable = false;

  # System-level packages (available to all users).
  environment.systemPackages = [ ];

  # System fonts (available to all apps).
  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  # Platform identifier for this host.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow specific unfree packages (home-manager inherits this via useGlobalPkgs).
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "claude-code-bin"
    ];

  # State version for nix-darwin. Set once on first build, never change.
  # Changing this can trigger irreversible state migrations.
  system.stateVersion = 5;
}
