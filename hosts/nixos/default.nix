{ lib, ... }:

{
  imports = [
    ./podman.nix
  ];
  # Enable flakes and nix-command by default
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Allow specific unfree packages (home-manager inherits this via useGlobalPkgs)
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  # Automatic garbage collection — weekly, keep the last 7 days of generations.
  # Without this, old store paths accumulate and fill the disk.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Deduplicate identical files in the Nix store (runs weekly after GC)
  nix.optimise.automatic = true;

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Enable nix-ld for running dynamically linked binaries (e.g. NuGet's Grpc.Tools protoc)
  programs.nix-ld.enable = true;

  # State version for NixOS. Set once on first build, never change.
  # This doesn't affect which packages you get — it controls state format
  # migrations. Changing it can trigger irreversible data migrations.
  system.stateVersion = "25.05";
}
