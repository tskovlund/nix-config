{ pkgs, ... }:

{
  # OpenCode — AI coding agent for the terminal (open-source).
  # https://github.com/anomalyco/opencode
  home.packages = [ pkgs.opencode ];

  # Shell alias: `oc` as shorthand for opencode.
  programs.zsh.initContent = ''
    alias oc='opencode'
  '';
}
