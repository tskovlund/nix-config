# examples/local-system.nix — template for machine-local NixOS system config
#
# Copy to ~/.config/nix-config/local-system.nix and customize.
# Apply with: make switch IMPURE=1
#
# This is a standard NixOS module. You can use any system-level option:
# - security.pki.certificateFiles for extra trusted certificates
# - networking.* for network configuration
# - services.* for system services
# - Any other NixOS option that can't go in home-manager
{ pkgs, ... }:

{
  # security.pki.certificateFiles = [
  #   /home/<user>/.local/share/dev-certs/dotnet-dev-cert.pem
  # ];
}
