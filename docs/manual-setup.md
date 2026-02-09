# Manual setup

Some things can't be declared in Nix. This is the checklist for new machines after `make switch`.

## macOS

### iTerm2

- **Font**: Preferences → Profiles → Text → Font → select "FiraCode Nerd Font"
  - FiraCode Nerd Font is installed by nix-darwin, but iTerm2's font preference must be set manually (iTerm2 rewrites its plist, making Nix management fragile)

### Determinate Nix

- First bootstrap may require: `sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin`
  - Only needed if Determinate Nix owns `/etc/zshenv` before nix-darwin is installed

## All platforms

### GitHub CLI

- Run `gh auth login` after first deploy to authenticate git operations

## Cleanup

### home-manager backup files

When home-manager encounters existing files it needs to manage, it renames them with a `.hm-backup` extension. After verifying everything works, search for and remove these:

```sh
find ~ -name "*.hm-backup" -maxdepth 3
```
