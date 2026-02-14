{ config, ... }:

{
  imports = [
    ./shell
    ./git
    ./tools
    ./editor
    ./claude
    ./ssh
  ];

  # Agenix identity — the age key used to decrypt secrets during activation.
  # Generated once per machine via: age-keygen -o ~/.config/agenix/age-key.txt
  # Only needed on machines that use the personal profile with secrets.
  age.identityPaths = [ "${config.home.homeDirectory}/.config/agenix/age-key.txt" ];

  # State version for home-manager. Set once on first build, never change.
  # This doesn't affect which packages you get — it controls state format
  # migrations. Changing it can trigger irreversible data migrations.
  home.stateVersion = "25.11";
}
