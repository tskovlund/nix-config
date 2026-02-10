{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      # Case-insensitive tab completion
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # iTerm2 shell integration (command framing, clickable marks, etc.)
      if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
        if [ ! -e "$HOME/.iterm2_shell_integration.zsh" ]; then
          curl -Ls https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"
        fi
        source "$HOME/.iterm2_shell_integration.zsh"
      fi

      # Show alias expansion before execution (for learning)
      # Inspired by ohare93/nixfiles
      _alias_expansion_preexec() {
        local cmd="$1"
        local first_word="''${cmd%% *}"
        local rest="''${cmd#"$first_word"}"
        local alias_def="$(alias "$first_word" 2>/dev/null)"

        if [[ -n "$alias_def" ]]; then
          local expansion="''${alias_def#*=}"
          # Strip surrounding quotes from the alias value
          expansion="''${expansion#\'}"
          expansion="''${expansion%\'}"
          printf '\033[2m→ %s%s\033[0m\n' "$expansion" "$rest" >&2
        fi
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook preexec _alias_expansion_preexec
    '';

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
      format = "$directory$git_branch$git_status$nix_shell$python$nodejs$rust$fill$cmd_duration$username$hostname $time$line_break$character";

      username = {
        show_always = true;
        format = "[$user]($style)";
      };

      hostname = {
        ssh_only = false;
        format = "[@$hostname]($style)";
      };

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
        symbol = "󱄅 ";
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

  programs.zsh.shellAliases = {
    cat = "bat";
    aliases = "alias | sed 's/=/ → /' | sort | bat --plain --language=sh";
  };

  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
  };

  home.sessionPath = [ "$HOME/.local/bin" ];
}
