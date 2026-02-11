{ ... }:

{
  homebrew = {
    # Personal casks — only on personal machines.
    casks = [
      # Chat
      "discord"
      "signal"
      "slack"

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

      # Notes
      "notesnook"

      # Utilities
      "qbittorrent"

      # AI
      "claude"
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
      "Proton Pass for Safari" = 6502835663;
      "WhatsApp" = 310633997;
    };
  };
}
