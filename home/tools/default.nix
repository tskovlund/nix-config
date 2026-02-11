{ pkgs, ... }:

{
  # zoxide: smart cd that learns your most-used directories
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # fzf: fuzzy finder (Ctrl+T files, Ctrl+R history, Alt+C directories)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--border"
    ];
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };

  # direnv: per-project environments via .envrc
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
  };

  # eza: modern ls with git status and icons
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
  };

  # ripgrep: fast recursive grep
  programs.ripgrep = {
    enable = true;
    arguments = [ "--smart-case" ];
  };

  # fd: fast file finder (respects .gitignore)
  programs.fd = {
    enable = true;
    hidden = true;
    ignores = [ ".git/" ];
  };

  # jq: JSON processor
  programs.jq.enable = true;

  # tealdeer: fast tldr client (community-maintained command cheatsheets)
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  # btop: system monitor
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "Default";
      theme_background = false;
    };
  };

  home.packages = with pkgs; [
    # Nix tooling
    home-manager # standalone CLI (generations, packages, etc.)

    # CLI toolkit
    yq # YAML processor (jq for YAML)
    wget # HTTP file downloads
    tree # directory tree visualization
    devbox # portable dev environments for non-Nix contributors
    podman # daemonless container engine (Docker-compatible)
    typst # modern typesetting (LaTeX alternative)
    catimg # display images in terminal
    glow # terminal markdown renderer

    # essentials
    sl
    cowsay
    lolcat
    fortune
    figlet
    ponysay
  ];
}
