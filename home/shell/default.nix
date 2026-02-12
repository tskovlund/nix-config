{ pkgs, ... }:

let
  # Computes a #RRGGBB hex color from a string via SHA-256 hash.
  # HSL color space: full hue range, saturation 65%, lightness 55-75%.
  # Output: just the hex color string, e.g. "#db6ce0"
  hashColorScript = pkgs.writeShellScript "hash-color" ''
    input="$1"

    # Portable SHA-256: macOS has shasum, Linux has sha256sum
    if command -v sha256sum >/dev/null 2>&1; then
      hash=$(printf '%s' "$input" | sha256sum | cut -c1-12)
    else
      hash=$(printf '%s' "$input" | shasum -a 256 | cut -c1-12)
    fi

    # Convert first 6 hex chars to an HSL color, then to RGB hex.
    # Uses awk for the math — runs once at shell init, not per prompt.
    ${pkgs.gawk}/bin/awk -v hash="$hash" 'BEGIN {
      hue_hex = substr(hash, 1, 4)
      lit_hex = substr(hash, 5, 2)

      hue_val = 0
      for (i = 1; i <= length(hue_hex); i++) {
        c = substr(hue_hex, i, 1)
        if (c ~ /[0-9]/) d = c + 0
        else d = (index("abcdef", tolower(c)) + 9)
        hue_val = hue_val * 16 + d
      }

      lit_val = 0
      for (i = 1; i <= length(lit_hex); i++) {
        c = substr(lit_hex, i, 1)
        if (c ~ /[0-9]/) d = c + 0
        else d = (index("abcdef", tolower(c)) + 9)
        lit_val = lit_val * 16 + d
      }

      h = (hue_val / 65535.0) * 360.0
      s = 0.65
      l = 0.55 + (lit_val / 255.0) * 0.20

      c = (1 - (2 * l - 1 > 0 ? 2 * l - 1 : -(2 * l - 1))) * s
      hp = h / 60.0
      x = c * (1 - ((hp % 2) - 1 > 0 ? (hp % 2) - 1 : -((hp % 2) - 1)))

      if      (hp < 1) { r1 = c; g1 = x; b1 = 0 }
      else if (hp < 2) { r1 = x; g1 = c; b1 = 0 }
      else if (hp < 3) { r1 = 0; g1 = c; b1 = x }
      else if (hp < 4) { r1 = 0; g1 = x; b1 = c }
      else if (hp < 5) { r1 = x; g1 = 0; b1 = c }
      else             { r1 = c; g1 = 0; b1 = x }

      m = l - c / 2
      r = int((r1 + m) * 255 + 0.5)
      g = int((g1 + m) * 255 + 0.5)
      b = int((b1 + m) * 255 + 0.5)

      printf "#%02x%02x%02x", r, g, b
    }'
  '';
in
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

      # Compute deterministic hash colors for username/hostname once at shell init.
      # Starship reads these env vars for styling — zero cost per prompt render.
      export STARSHIP_USER_COLOR="$(${hashColorScript} "$(whoami)")"
      export STARSHIP_HOST_COLOR="$(${hashColorScript} "$(hostname -s)")"
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

      # Hash-colored username/hostname: colors are computed once at shell init
      # and cached in STARSHIP_USER_COLOR / STARSHIP_HOST_COLOR env vars.
      username = {
        show_always = true;
        format = "[$user](bold \${env:STARSHIP_USER_COLOR})";
      };

      hostname = {
        ssh_only = false;
        format = "[@$hostname](bold \${env:STARSHIP_HOST_COLOR})";
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
