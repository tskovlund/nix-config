# Manual setup

After running `bootstrap.sh` and `make bootstrap`, these steps remain manual:

## macOS

- **iTerm2 font**: Preferences > Profiles > Text > Font > select "FiraCode Nerd Font"
  - Installed by nix-darwin, but iTerm2's font preference must be set manually (iTerm2 rewrites its plist)
- **fn-toggle permission**: System Settings > Privacy & Security > Accessibility > fn-toggle.app
  - Needs one-time permission grant on first run

## Linux / WSL

- **Nerd Font**: Install [FiraCode Nerd Font](https://www.nerdfonts.com/) (or another Nerd Font) in your terminal emulator
  - Fonts are rendered by the host terminal, not managed by Nix on Linux/WSL

## All platforms

- **Verify prompt**: Open a new terminal and confirm the starship prompt renders correctly

---

Everything else (Nix, Homebrew, /etc/zshenv, Mac App Store, ~/Screenshots, personal identity, GitHub CLI auth, home-manager backup cleanup) is handled by `bootstrap.sh` and `make bootstrap`. Claude Code settings are reconciled by `make switch` itself (see [`docs/features.md`](features.md#claude-code)).
