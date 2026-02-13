{ pkgs, ... }:

{
  # Determinate Nix manages the Nix daemon and settings (flakes, nix-command, etc.).
  # Disable nix-darwin's Nix management to avoid conflicts.
  # Trade-off: nix-darwin's `nix.*` options (like nix.settings) are unavailable.
  # Configure Nix settings via Determinate instead.
  nix.enable = false;

  # System-level packages (available to all users).
  environment.systemPackages = [ ];

  # System fonts (available to all apps).
  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  # Platform identifier for this host.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow specific unfree packages (home-manager inherits this via useGlobalPkgs).
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "claude-code-bin"
    ];

  # --- Homebrew (cask management) ---
  # Homebrew itself is installed separately (not managed by Nix).
  # nix-darwin's homebrew module manages what Homebrew installs declaratively.
  homebrew = {
    enable = true;

    # Remove casks/formulae not declared here on every rebuild.
    onActivation.cleanup = "zap";

    brews = [
      "mas"
    ];

    # Base casks — useful on any macOS machine.
    casks = [
      "firefox"
      "google-chrome"
      "iterm2"
      "podman-desktop"
      "scroll-reverser"
      "disk-inventory-x"
    ];

    # Mac App Store — base apps (requires being signed into the App Store).
    masApps = {
      "Amphetamine" = 937984704;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
    };
  };

  # --- Touch ID for sudo ---
  security.pam.services.sudo_local.touchIdAuth = true;

  # --- macOS system defaults ---
  system.defaults = {

    # Dock
    dock = {
      autohide = false;
      tilesize = 48;
      orientation = "bottom";
      show-recents = false;
      mru-spaces = false;
      minimize-to-application = true;
      mineffect = "scale";
      launchanim = false;
      show-process-indicators = true;
      showhidden = true;
      expose-group-apps = true; # Group windows by app in Mission Control
      magnification = false;
      largesize = 16;
      showAppExposeGestureEnabled = true; # Swipe down to show app windows
      # Hot corners (values: 1=disabled, 2=Mission Control, 4=Desktop, 5=Screen Saver, 13=Lock Screen)
      wvous-tl-corner = 5; # top-left: Start Screen Saver
      wvous-tr-corner = 4; # top-right: Desktop
      wvous-bl-corner = 1; # bottom-left: disabled
      wvous-br-corner = 1; # bottom-right: disabled
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv"; # Column view
      FXDefaultSearchScope = "SCcf"; # Search current folder
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXSortFoldersFirst = true;
      NewWindowTarget = "Home"; # New windows open Home
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
    };

    # Global preferences
    NSGlobalDomain = {
      # Keyboard
      ApplePressAndHoldEnabled = false; # Key repeat instead of accent popup
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      "com.apple.keyboard.fnState" = false; # Fn key = special keys (toggled by fn-toggle)

      # Appearance (auto-switches between light and dark based on time of day)
      AppleInterfaceStyleSwitchesAutomatically = true;

      # Disable text corrections
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;

      # Expanded dialogs by default
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;

      # Save to local disk, not iCloud
      NSDocumentSaveNewDocumentsToCloud = false;

      # Sidebar icon size (medium)
      NSTableViewDefaultSizeMode = 2;

      # Region & time
      AppleICUForce24HourTime = true;
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      AppleTemperatureUnit = "Celsius";

      # Scrolling & trackpad
      "com.apple.swipescrolldirection" = true; # Natural scrolling
      "com.apple.trackpad.forceClick" = true;
      "com.apple.trackpad.scaling" = 1.0;

      # Spring loading (drag-hover to open folders)
      "com.apple.springing.enabled" = true;
      "com.apple.springing.delay" = 0.5;

      # Sound
      "com.apple.sound.beep.volume" = 1.0;
      "com.apple.sound.beep.feedback" = 1;

    };

    # Trackpad
    trackpad = {
      Clicking = true; # Tap to click
      TrackpadRightClick = true; # Two-finger right-click
      TrackpadThreeFingerDrag = true;
      ActuationStrength = 0; # Silent clicking
      FirstClickThreshold = 2; # Firm click
      SecondClickThreshold = 2; # Firm force touch
      TrackpadMomentumScroll = true; # Inertia scrolling
      TrackpadPinch = true; # Pinch to zoom
      TrackpadRotate = true; # Two-finger rotate
      TrackpadTwoFingerDoubleTapGesture = true; # Smart zoom
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3; # Swipe from right edge for Notification Center
      TrackpadThreeFingerHorizSwipeGesture = 2; # Three-finger swipe between spaces
      TrackpadThreeFingerVertSwipeGesture = 2; # Three-finger Mission Control / App Expose
      TrackpadFourFingerHorizSwipeGesture = 2; # Four-finger swipe between spaces
      TrackpadFourFingerVertSwipeGesture = 2; # Four-finger Mission Control / App Expose
      TrackpadFourFingerPinchGesture = 2; # Four-finger pinch for Launchpad / spread for Desktop
    };

    # Screenshots
    screencapture = {
      location = "~/Screenshots";
      type = "png";
      disable-shadow = true;
    };

    # Fn key: Show Emoji & Symbols
    hitoolbox.AppleFnUsageType = "Show Emoji & Symbols";

    # Control center / menu bar
    controlcenter = {
      BatteryShowPercentage = true;
      Bluetooth = true;
      Sound = true;
      AirDrop = true;
      Display = false;
      FocusModes = true;
      NowPlaying = true;
    };

    # Siri
    CustomSystemPreferences."com.apple.Siri".StatusMenuVisible = false;

    # Screen saver & lock
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    # Login window
    loginwindow.GuestEnabled = false;

    # Activity Monitor
    ActivityMonitor.ShowCategory = 100; # All processes

    # Window management
    WindowManager.EnableTilingByEdgeDrag = true;

    # Menu bar clock
    menuExtraClock = {
      Show24Hour = true;
      ShowDayOfWeek = true;
    };

    # Disable quarantine dialog for downloaded apps
    LaunchServices.LSQuarantine = false;

    # No .DS_Store on network/USB drives
    CustomUserPreferences = {
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      # Settings not natively supported by nix-darwin
      NSGlobalDomain = {
        "com.apple.mouse.scaling" = 0.125;
        AppleLanguages = [
          "en-US"
          "da-DK"
        ];
        AppleLocale = "en_US@rg=dkzzzz";
      };
      # Clipboard history (requires macOS Sequoia or later; safely ignored on older versions)
      "com.apple.Spotlight" = {
        PasteboardHistoryEnabled = true;
        PasteboardHistoryTimeout = 604800; # 7 days
      };
      # AirDrop discoverability
      "com.apple.sharingd".DiscoverableMode = "Contacts Only";
      # Screen saver idle time (not natively supported by nix-darwin)
      "com.apple.screensaver".idleTime = 600;
    };
  };

  # Exclude /nix from Time Machine and Spotlight (immutable, reproducible, huge)
  system.activationScripts.extraActivation.text = ''
    /usr/bin/tmutil addexclusion -p /nix/store 2>/dev/null || true
    /usr/bin/mdutil -i off /nix 2>/dev/null || true
  '';

  # State version for nix-darwin. Set once on first build, never change.
  # Changing this can trigger irreversible state migrations.
  system.stateVersion = 5;
}
