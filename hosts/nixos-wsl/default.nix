{ ... }:

{
  # Import general WSL layer (interop, automount, start menu launchers).
  # The general NixOS layer (hosts/nixos) is imported by makeNixOS in flake.nix.
  imports = [
    ../wsl
  ];
}
