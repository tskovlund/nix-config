# Manual setup

Some things can't be declared in Nix. This is the checklist for new machines after `make switch`.

## macOS

### iTerm2

- **Font**: Preferences → Profiles → Text → Font → select "FiraCode Nerd Font"
  - FiraCode Nerd Font is installed by nix-darwin, but iTerm2's font preference must be set manually (iTerm2 rewrites its plist, making Nix management fragile)

### Determinate Nix

- First bootstrap may require: `sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin`
  - Only needed if Determinate Nix owns `/etc/zshenv` before nix-darwin is installed

## Linux / WSL

### Fonts

On macOS, nix-darwin installs FiraCode Nerd Font system-wide. On Linux/WSL there is no display server — fonts are rendered by the terminal emulator on the host. Install a [Nerd Font](https://www.nerdfonts.com/) (e.g. FiraCode Nerd Font) in your terminal emulator to get correct glyphs in the starship prompt and Neovim.

## All platforms

### Claude Code

The statusline script is managed by Nix (symlinked to `~/.claude/statusline-command.sh`). Settings and plugins are not — Claude Code reads and writes `~/.claude/settings.json` at runtime (e.g. when toggling plugins), so it needs to stay writable.

After first deploy, configure `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "Notion@claude-plugins-official": true,
    "linear@claude-plugins-official": true
  },
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

Install additional plugins as needed via `/plugins` inside Claude Code.

### GitHub CLI

- Run `gh auth login` after first deploy to authenticate git operations

## Cleanup

### home-manager backup files

When home-manager encounters existing files it needs to manage, it renames them with a `.hm-backup` extension. After verifying everything works, search for and remove these:

```sh
find ~ -name "*.hm-backup" -maxdepth 3
```
