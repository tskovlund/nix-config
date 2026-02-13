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
- **MCP memory server**: Register with Claude Code (one-time):
  ```sh
  claude mcp add --transport stdio --scope user memory -- \
    ~/.local/bin/mcp-server-memory
  ```
  Verify with `claude mcp list`. Memory data is stored at `~/.local/share/claude-memory/memory.jsonl`.

---

Everything else (Nix, Homebrew, /etc/zshenv, Mac App Store, ~/Screenshots, personal identity, GitHub CLI auth, Claude Code settings, home-manager backup cleanup) is handled by `bootstrap.sh` and `make bootstrap`.
