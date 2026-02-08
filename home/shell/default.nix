{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      extended = true;
      share = true;
    };
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$directory$git_branch$git_status$nix_shell$python$nodejs$rust$fill$cmd_duration$time$line_break$character";

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        ahead = "↑$count";
        behind = "↓$count";
        diverged = "↑$ahead_count↓$behind_count";
        staged = "+$count";
        modified = "!$count";
        untracked = "?$count";
        deleted = "✘$count";
        renamed = "»$count";
        stashed = "\\$$count";
        conflicted = "=$count";
      };

      fill.symbol = "·";

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
      };

      time = {
        disabled = false;
        format = "[$time]($style)";
        time_format = "%H:%M:%S";
      };

      nix_shell = {
        format = "via [$symbol$state]($style) ";
        symbol = "❄️ ";
      };

      python.format = "via [$symbol$version]($style) ";
      nodejs.format = "via [$symbol$version]($style) ";
      rust.format = "via [$symbol$version]($style) ";
    };
  };

  # bat: syntax-highlighted cat replacement + man pager
  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
      style = "numbers,changes";
    };
  };

  programs.zsh.shellAliases.cat = "bat";

  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
  };

  home.sessionPath = [ "$HOME/.local/bin" ];
}
