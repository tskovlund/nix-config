{ pkgs, ... }:

{
  imports = [
    ./claude
  ];

  # Personal additions layered on top of the base dev environment.
  # Only imported by the "darwin" / "linux" targets, not "darwin-base" / "linux-base".
  #
  # Put personal aliases, fun tools, personal SSH hosts, etc. here.
  # If something would be useful on any dev machine, it belongs in default.nix instead.
}
