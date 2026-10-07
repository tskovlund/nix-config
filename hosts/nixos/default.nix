{ lib, pkgs, ... }:

{
  imports = [
    ./podman.nix
  ];
  # Enable flakes and nix-command by default
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Unfree packages are allowed via the shared predicate set in flake.nix
  # (home-manager inherits it via useGlobalPkgs).

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

  # `make switch` is the entry point, and NixOS doesn't ship make.
  environment.systemPackages = [ pkgs.gnumake ];

  # nix-ld runs foreign dynamically linked binaries on NixOS. Claude Code's
  # self-updated binary (~/.local/bin/claude) depends on it, as do most
  # vendor-downloaded tools (NuGet's Grpc.Tools protoc, VS Code server, ...).
  programs.nix-ld.enable = true;

  # State version for NixOS. Set once on first build, never change.
  # This doesn't affect which packages you get — it controls state format
  # migrations. Changing it can trigger irreversible data migrations.
  # A default only: a machine installed from a newer NixOS keeps its install
  # value, set in ~/.config/nix-config/local-system.nix.
  system.stateVersion = lib.mkDefault "25.05";
}
