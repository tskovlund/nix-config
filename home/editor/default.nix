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
    ./lean.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Reuse the already-instantiated nixpkgs instead of nixvim's own pin.
    # Our flake `follows` overrides nixvim's nixpkgs anyway; declaring it
    # explicitly keeps the single-nixpkgs policy and silences the mismatch
    # warning nixvim emits when `follows` diverges from its pinned default.
    nixpkgs.pkgs = pkgs;
  };
}
