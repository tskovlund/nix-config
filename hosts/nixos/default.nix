{ lib, ... }:

{
  # Enable flakes and nix-command by default
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Allow specific unfree packages (home-manager inherits this via useGlobalPkgs)
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code-bin"
    ];

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # State version for NixOS. Set once on first build, never change.
  # This doesn't affect which packages you get — it controls state format
  # migrations. Changing it can trigger irreversible data migrations.
  system.stateVersion = "25.05";
}
