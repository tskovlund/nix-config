{ pkgs, ... }:

let
  fn-toggle = pkgs.stdenvNoCC.mkDerivation {
    pname = "fn-toggle";
    version = "unstable-2021-09-08";

    src = pkgs.fetchFromGitHub {
      owner = "jkbrzt";
      repo = "macos-fn-toggle";
      rev = "8e478278d67873bc2438a924dfd7de7b38cc71eb";
      sha256 = "sha256-cvHB++XFPnVTB+Gi8IpnoE//bC4SYKVxkh00d6d/yqU=";
    };

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/Applications
      cp -r fn-toggle.app $out/Applications/
    '';

    meta = {
      description = "Toggle macOS fn key behavior (standard function keys vs media keys)";
      homepage = "https://github.com/jkbrzt/macos-fn-toggle";
      platforms = pkgs.lib.platforms.darwin;
    };
  };
in
{
  # Homebrew is installed separately (not managed by Nix) but nix-darwin's
  # homebrew module uses it to manage casks/formulae declaratively.
  # Add to PATH so brew is also available for manual use.
  home.sessionPath = [ "/opt/homebrew/bin" ];

  # fn-toggle: toggle fn key behavior via Spotlight (Cmd+Space → "fn").
  # Requires granting accessibility permissions on first run:
  # System Settings → Privacy & Security → Accessibility → fn-toggle.app
  home.packages = [ fn-toggle ];

  # iTerm2 is the terminal installed by hosts/darwin (cask). Both blocks
  # below only make sense there: the shell integration script is fetched
  # from iterm2.com on first use, and `ct` relies on tmux -CC (iTerm2
  # control mode) so agent-team splits render as native iTerm2 panes.
  #
  #   ct / claude-team — launch Claude Code inside tmux -CC for agent teams
  programs.zsh.initContent = ''
    # iTerm2 shell integration (command framing, clickable marks, etc.)
    if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
      if [ ! -e "$HOME/.iterm2_shell_integration.zsh" ]; then
        curl -Ls https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"
      fi
      source "$HOME/.iterm2_shell_integration.zsh"
    fi

    alias claude-team='ct'
    ct() {
      if [ -n "$TMUX" ]; then
        command claude --teammate-mode tmux "$@"
      else
        tmux -CC new-session "command claude --teammate-mode tmux $*"
      fi
    }
  '';

  # Store SSH key passphrases in the macOS Keychain. Combined with
  # addKeysToAgent (set in home/ssh/), you type your passphrase once
  # and Keychain remembers it across reboots.
  programs.ssh.extraConfig = ''
    UseKeychain yes
  '';
}
