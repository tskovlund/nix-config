{
  username,
  pkgs,
  lib,
  ...
}:

{
  # Stage Manager — personal preference, not in base config.
  system.defaults.WindowManager.GloballyEnabled = true;

  homebrew = {
    # Personal casks — only on personal machines.
    casks = [
      # Chat
      "discord"
      "signal"
      "slack"
      "telegram"

      # Productivity
      "notion"
      "linear-linear"

      # Privacy / Security
      "proton-mail"
      "proton-drive"
      "proton-pass"
      "protonvpn"
      "ente-auth"

      # Media
      "tidal"
      "pocket-casts"
      "gimp"
      "audacity"
      "vlc"
      "musescore"
      "plex-media-server"

      # Gaming
      "steam"
      "zwift"

      # Notes
      "notesnook"

      # Networking
      "tailscale-app"

      # Audio
      "focusrite-control"

      # Utilities
      "qbittorrent"
    ];

    # Mac App Store apps (requires being signed into the App Store).
    masApps = {
      "Compressor" = 424390742;
      "Final Cut Pro" = 424389933;
      "GarageBand" = 682658836;
      "iMovie" = 408981434;
      "Logic Pro" = 634148309;
      "MainStage" = 634159523;
      "Motion" = 434290957;
      "WhatsApp" = 310633997;
    };
  };

  # Dock layout — apps in preferred order.
  # Finder and Trash are always present (managed by macOS, not included here).
  # Known issue: nix-darwin #1250 — non-system apps may show as question marks
  # on macOS Sequoia 15.2+. If so, re-pin manually; upstream fix pending.
  system.defaults.dock.persistent-apps = [
    "/Applications/Firefox.app"
    "/Applications/iTerm.app"
    "/Applications/Podman Desktop.app"
    "/Applications/Proton Pass.app"
    "/Applications/Ente Auth.app"
    "/Applications/ProtonVPN.app"
    "/Applications/Tailscale.app"
    "/Applications/TIDAL.app"
    "/System/Applications/Music.app"
    "/Applications/Pocket Casts.app"
    "/Applications/VLC.app"
    "/Applications/Slack.app"
    "/Applications/Linear.app"
    "/Applications/Notion.app"
    "/Applications/Notesnook.app"
    "/Applications/Proton Mail.app"
    "/System/Applications/Mail.app"
    "/Applications/Signal.app"
    "/Applications/Telegram.app"
    "/System/Applications/Messages.app"
    "/System/Applications/FaceTime.app"
    "/Applications/WhatsApp.app"
    "/System/Applications/Notes.app"
    "/System/Applications/Photos.app"
    "/Applications/Zwift.app"
    "/Applications/MuseScore 4.app"
    "/Applications/Focusrite Control.app"
    "/System/Applications/Utilities/Audio MIDI Setup.app"
    "/Applications/Logic Pro.app"
    "/Applications/MainStage.app"
    "/Applications/Final Cut Pro.app"
    "/Applications/Compressor.app"
    "/Applications/Motion.app"
    "/Applications/Discord.app"
    "/Applications/Steam.app"
    "/System/Applications/System Settings.app"
  ];

  system.defaults.dock.persistent-others = [
    {
      folder = {
        path = "/Users/${username}/Downloads";
        displayas = "stack";
        showas = "automatic";
      };
    }
  ];

  # Personal post-activation: file type associations + login items.
  # Uses postActivation (a well-known hook that actually runs). Custom-named
  # activationScripts (like the old setDefaultApps / setLoginItems) are defined
  # but never wired into the execution order — only well-known hooks run.
  # Both duti and osascript need sudo -u because activation runs as root.
  system.activationScripts.postActivation.text =
    let
      duti = "${pkgs.duti}/bin/duti";
      setDefault = id: ext: "sudo -u ${username} ${duti} -s ${id} ${ext} all 2>/dev/null || true\n";
      iterm = "com.googlecode.iterm2";
      vlc = "org.videolan.vlc";

      loginItems = [
        {
          path = "/Applications/Scroll Reverser.app";
          name = "Scroll Reverser";
        }
        {
          path = "/Applications/Amphetamine.app";
          name = "Amphetamine";
        }
        {
          path = "/Applications/ProtonVPN.app";
          name = "ProtonVPN";
        }
        {
          path = "/Applications/Tailscale.app";
          name = "Tailscale";
        }
      ];
      deleteItem = item: ''
        sudo -u ${username} osascript -e 'tell application "System Events" to delete login item "${item.name}"' 2>/dev/null || true
      '';
      addItem = item: ''
        sudo -u ${username} osascript -e 'tell application "System Events" to make login item at end with properties {path:"${item.path}", hidden:false}' 2>/dev/null || true
      '';
    in
    ''
      echo "Setting default file type associations..."
    ''
    # Code / text files → iTerm2
    + setDefault iterm ".md"
    + setDefault iterm ".txt"
    + setDefault iterm ".json"
    + setDefault iterm ".yaml"
    + setDefault iterm ".yml"
    + setDefault iterm ".toml"
    + setDefault iterm ".nix"
    + setDefault iterm ".js"
    + setDefault iterm ".ts"
    + setDefault iterm ".py"
    + setDefault iterm ".sh"
    # Data → Numbers
    + setDefault "com.apple.iWork.Numbers" ".csv"
    # SVG → Firefox
    + setDefault "org.mozilla.firefox" ".svg"
    # Images → Preview
    + setDefault "com.apple.Preview" ".webp"
    # Media → VLC
    + setDefault vlc ".mp4"
    + setDefault vlc ".mkv"
    + setDefault vlc ".avi"
    + setDefault vlc ".webm"
    # Login items
    + ''
      echo "Setting login items..."
      ${builtins.concatStringsSep "" (map deleteItem loginItems)}
      ${builtins.concatStringsSep "" (map addItem loginItems)}
    '';
}
