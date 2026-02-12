{ ... }:

{
  # Import general NixOS and WSL layers
  imports = [
    ../nixos
    ../wsl
  ];

  # NixOS-WSL specific configuration will be applied via the
  # nixos-wsl.nixosModules.wsl module imported in flake.nix
}
