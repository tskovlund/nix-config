{ ... }:

{
  # Import general WSL layer (interop, automount, start menu launchers).
  # The general NixOS layer (hosts/nixos) is imported by makeNixOS in flake.nix.
  # ./ollama.nix needs an NVIDIA GPU, so only the personal target imports it.
  imports = [
    ../wsl
  ];
}
