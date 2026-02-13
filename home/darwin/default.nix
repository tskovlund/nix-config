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

  # Store SSH key passphrases in the macOS Keychain. Combined with
  # addKeysToAgent (set in home/ssh/), you type your passphrase once
  # and Keychain remembers it across reboots.
  programs.ssh.extraConfig = ''
    UseKeychain yes
  '';
}
