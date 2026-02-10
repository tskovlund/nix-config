{ pkgs, ... }:

{
  imports = [
    ./options.nix
    ./keymaps.nix
    ./ui.nix
    ./completion.nix
    ./lsp.nix
    ./git.nix
    ./navigation.nix
    ./utilities.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
