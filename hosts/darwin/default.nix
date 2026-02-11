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

  # --- Homebrew (cask management) ---
  # Homebrew itself is installed separately (not managed by Nix).
  # nix-darwin's homebrew module manages what Homebrew installs declaratively.
  homebrew = {
    enable = true;

    # Remove casks/formulae not declared here on every rebuild.
    onActivation.cleanup = "zap";

    brews = [
      "mas"
    ];

    # Base casks — useful on any macOS machine.
    casks = [
      "firefox"
      "google-chrome"
      "iterm2"
      "podman-desktop"
      "scroll-reverser"
      "disk-inventory-x"
    ];

    # Mac App Store — base apps (requires being signed into the App Store).
    masApps = {
      "Amphetamine" = 937984704;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
    };
  };

  # State version for nix-darwin. Set once on first build, never change.
  # Changing this can trigger irreversible state migrations.
  system.stateVersion = 5;
}
