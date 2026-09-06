# examples/local.nix — template for machine-local config
#
# Copy to ~/.config/nix-config/local.nix and customize.
# Apply with: make switch IMPURE=1
#
# This is a standard home-manager module. You can use any option:
# - home.packages for extra packages
# - programs.* for program configuration
# - home.file for dotfile management
# - home.sessionVariables for environment variables
#
# Work SDKs belong here rather than in the shared base profile. On a machine
# that needs .NET, copy this file as-is and run `make switch IMPURE=1`.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dotnet-sdk_10 # .NET 10 SDK
    # azure-cli
    # terraform
  ];
}
