{ pkgs, ... }:

{
  imports = [
    ./shell
    ./git
    ./tools
    ./editor
  ];

  # State version for home-manager. Set once on first build, never change.
  # This doesn't affect which packages you get — it controls state format
  # migrations. Changing it can trigger irreversible data migrations.
  home.stateVersion = "25.11";
}
