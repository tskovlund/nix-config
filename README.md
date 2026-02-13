# nix-config ❄️

Fully declarative, cross-platform environment using Nix flakes, nix-darwin, and home-manager.

Everything about your environment — shell, editor, git, CLI tools, system preferences — is defined as code in this repo. Applying the config on a new machine reproduces the entire setup exactly.

- **macOS**: nix-darwin manages system settings + home-manager manages user config
- **Linux / WSL**: standalone home-manager manages user config

## Quick start 🚀

```sh
# 1. Install Nix (Determinate installer recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. macOS only: install Homebrew (nix-darwin manages what it installs, but not Homebrew itself)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Clone and deploy
git clone https://github.com/tskovlund/nix-config.git
cd nix-config

# macOS (first time — subsequent deploys: make switch)
nix build .#darwinConfigurations.darwin.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#darwin

# Linux / WSL (first time — subsequent deploys: make switch)
nix run home-manager -- switch --flake .#linux
```

See [Prerequisites](#prerequisites-) for full details.

## Highlights ✨

- **[Starship](https://starship.rs/) prompt** with deterministic hash-colored hostname and username — each machine gets a unique, consistent color so you always know where you are
- **Full-fledged [Neovim](https://neovim.io/)** via [nixvim](https://github.com/nix-community/nixvim) — LSP, completion, format-on-save, telescope, treesitter, and more ([details below](#editor))
- **Case-insensitive tab completion** and [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) out of the box
- **Touch ID for sudo** — no more typing passwords in the terminal
- **Opinionated CLI toolkit** — [bat](https://github.com/sharkdp/bat) as cat/man pager, [delta](https://github.com/dandavison/delta) for diffs, [eza](https://github.com/eza-community/eza) for ls, [zoxide](https://github.com/ajeetdsouza/zoxide) for cd, [fzf](https://github.com/junegunn/fzf) for everything else
- **[direnv](https://github.com/direnv/direnv) + [nix-direnv](https://github.com/nix-community/nix-direnv)** — automatic per-project dev environments
- ...and a lot more good stuff. See [What's included](#whats-included-) for the full inventory.

## Profiles 🧩

The config is split into two composable layers:

- **base** (`home/default.nix`) — dev environment essentials: shell, editor, git, CLI tools. Everything you'd want on any dev machine, including a work laptop.
- **personal** (`home/personal.nix`) — personal additions layered on top of base. Personal aliases, fun tools, personal SSH hosts, etc.

Each platform has two targets:

| Target | What it includes | Use case |
|--------|-----------------|----------|
| `darwin` / `linux` | base + personal | Personal machines |
| `darwin-base` / `linux-base` | base only | Shared or work machines |

## Machine-local config 🔧

For machine-specific packages that don't belong in the repo (work SDKs, vendor CLIs, experimental tools), create an optional local config file:

```sh
mkdir -p ~/.config/nix-config
```

```nix
# ~/.config/nix-config/local.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dotnet-sdk_8
    azure-cli
  ];
}
```

This is a standard home-manager module — any option from `programs.*`, `home.file`, `home.sessionVariables`, etc. works here. See [`examples/local.nix`](examples/local.nix) for a starter template.

To apply it, pass `IMPURE=1`:

```sh
make switch IMPURE=1
```

Without `IMPURE=1`, the local file is silently ignored — pure evaluation cannot read paths outside the Nix store. This is intentional: CI and `nix flake check` always run in pure mode and are unaffected.

> For config that should be reproducible across reinstalls, consider extracting it into a separate flake (e.g. an org-level dev environment) instead of using local.nix.

## Prerequisites 📋

1. **Install Nix** — we recommend the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

   This installs Nix with flakes and the `nix` command enabled by default. If you use the [official installer](https://nixos.org/download/) instead, you'll need to enable `experimental-features = nix-command flakes` in `~/.config/nix/nix.conf`.

2. **macOS only: Install Homebrew** — https://brew.sh. nix-darwin manages what Homebrew installs (casks, Mac App Store apps), but Homebrew itself must be installed first. Also sign into the Mac App Store before deploying.

3. **Clone this repo**:

   ```sh
   git clone https://github.com/tskovlund/nix-config.git
   cd nix-config
   ```

4. **Personalize** — edit the `username` variable at the top of `flake.nix`:

   ```nix
   let
     username = "your-username-here";
   in
   ```

   This single variable flows through to all configs (home directory, home-manager user, etc.).

## Deploy 🚀

### macOS (first time)

Bootstrap nix-darwin — build the config, then activate as root:

```sh
nix build .#darwinConfigurations.darwin.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#darwin
```

If `/etc/zshenv` (or other files in `/etc/`) conflict, rename them first:

```sh
sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin
```

### Linux / WSL (first time)

If `home-manager` isn't on your PATH yet, bootstrap it:

```sh
nix run home-manager -- switch --flake .#linux
```

### Subsequent deploys

The Makefile auto-detects your platform:

```sh
make switch         # base + personal
make switch-base    # base only
```

### Why `--flake .#darwin` instead of just `--flake .`?

nix-darwin auto-detects configs by matching your machine's hostname. We use generic config names (`darwin`, `linux`) so the repo works on any machine without renaming entries per host. The trade-off is one extra flag — the Makefile handles this for you.

## Repo structure 📁

```
nix-config/
├── flake.nix                    # Entry point: inputs + all targets
├── flake.lock                   # Pinned dependency versions
├── Makefile                     # Convenience targets (make switch, etc.)
│
├── hosts/
│   ├── darwin/default.nix       # macOS base system config (nix-darwin, base casks, system defaults)
│   ├── darwin/personal.nix      # macOS personal casks + Mac App Store apps
│   └── linux/default.nix        # Linux system config (placeholder)
│
├── home/
│   ├── default.nix              # Base dev environment (always imported)
│   ├── personal.nix             # Personal additions (imported by non-base targets)
│   ├── darwin/                  # macOS-only home-manager config (Homebrew PATH, etc.)
│   ├── shell/                   # Zsh, starship prompt, bat
│   ├── editor/                  # Neovim via nixvim (LSP, completion, themes)
│   ├── git/                     # Git, delta, gh CLI
│   ├── tools/                   # CLI toolkit, direnv, fzf
│   └── claude/                  # Claude Code + statusline script
│
├── examples/                    # Templates (local.nix, etc.)
├── .githooks/                   # Repo-local git hooks (pre-push)
├── .envrc                       # direnv config (auto-enters dev shell)
├── files/                       # Raw config files sourced by modules
└── secrets/                     # agenix encrypted secrets
```

## What's included 🧰

### Shell
- [zsh](https://www.zsh.org/) with [starship](https://starship.rs/) prompt, [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [bat](https://github.com/sharkdp/bat) — syntax-highlighted cat replacement + man pager
- [FiraCode Nerd Font](https://github.com/tonsky/FiraCode)

### Editor
- [Neovim](https://neovim.io/) via [nixvim](https://github.com/nix-community/nixvim) — fully declarative, typed Nix configuration
- [TokyoNight](https://github.com/folke/tokyonight.nvim) theme (night) with 5 extra themes available via `<leader>cs` picker
- LSP support: nixd, pyright, ruff, ts_ls, rust-analyzer, clangd, omnisharp, fsautocomplete, jdtls, lua_ls
- [telescope](https://github.com/nvim-telescope/telescope.nvim) — fuzzy finder for files, grep, buffers, and more
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) — completion with LSP, snippets, buffer, and path sources
- [conform.nvim](https://github.com/stevearc/conform.nvim) — format on save (nixfmt, ruff, prettier, rustfmt, stylua)
- [treesitter](https://github.com/nvim-treesitter/nvim-treesitter) — syntax highlighting and smart indentation
- [oil.nvim](https://github.com/stevearc/oil.nvim) — buffer-based file explorer
- [flash.nvim](https://github.com/folke/flash.nvim) — enhanced motion and jump
- [gitsigns](https://github.com/lewis6991/gitsigns.nvim) — git signs and inline blame
- [which-key](https://github.com/folke/which-key.nvim) — keybind discovery popup
- [lualine](https://github.com/nvim-lualine/lualine.nvim) — statusline with mode, branch, diagnostics, clock

### Git
- [delta](https://github.com/dandavison/delta) — syntax-highlighted diffs
- [gh](https://cli.github.com/) — GitHub CLI with credential helper

### CLI toolkit
- [zoxide](https://github.com/ajeetdsouza/zoxide) — smart cd that learns your most-used directories
- [fzf](https://github.com/junegunn/fzf) — fuzzy finder for files, history, and directories
- [ripgrep](https://github.com/BurntSushi/ripgrep) — fast recursive grep
- [fd](https://github.com/sharkdp/fd) — fast file finder that respects .gitignore
- [eza](https://github.com/eza-community/eza) — modern ls with git status and icons
- [jq](https://github.com/jqlang/jq) / [yq](https://github.com/kislyuk/yq) — JSON and YAML processors
- [tealdeer](https://github.com/dbrgn/tealdeer) — fast tldr client (community-maintained command cheatsheets)
- [btop](https://github.com/aristocratos/btop) — system monitor
- [direnv](https://github.com/direnv/direnv) + [nix-direnv](https://github.com/nix-community/nix-direnv) — per-project dev environments via .envrc
- [devbox](https://github.com/jetify-com/devbox) — portable dev environments for non-Nix contributors
- [typst](https://github.com/typst/typst) — modern typesetting (LaTeX alternative)
- [glow](https://github.com/charmbracelet/glow) — terminal markdown renderer
- [catimg](https://github.com/posva/catimg) — display images in terminal
- [tree](https://mama.indstate.edu/users/ice/tree/) — directory tree visualization
- [wget](https://www.gnu.org/software/wget/) — HTTP file downloads
- [sl](https://github.com/mtoyoda/sl), [cowsay](https://github.com/tnalpgge/rank-amateur-cowsay), [lolcat](https://github.com/busyloop/lolcat), [fortune](https://github.com/shlomif/fortune-mod), [figlet](http://www.figlet.org/), [ponysay](https://github.com/erkin/ponysay)

### macOS system defaults (nix-darwin)
- Dock, Finder, keyboard, trackpad (all gestures), screenshots, Stage Manager, hot corners
- Control center / menu bar visibility, screensaver, login window, Activity Monitor
- Touch ID for sudo, clipboard history, language/region, AirDrop
- [fn-toggle](https://github.com/jkbrzt/macos-fn-toggle) — toggle fn key behavior via Spotlight (packaged as Nix derivation)

### Claude Code (personal profile only)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — AI coding assistant CLI
- Custom statusline showing directory, git status, model, context usage, cost, and session info (aligned with starship prompt style)

## Development 🛠️

After deploying the config (which installs direnv), allow direnv to enter the dev shell:

```sh
cd ~/repos/nix-config
direnv allow
```

This automatically sets up commit hooks — pre-commit formats and lints `.nix` files, pre-push runs `nix flake check --all-systems`. If direnv isn't available yet (fresh clone before first deploy), you can set up hooks manually:

```sh
git config core.hooksPath .githooks
```

CI also validates both Linux and macOS on every PR.

## Common tasks 🔧

| Task | Command |
|------|---------|
| Apply config (base + personal) | `make switch` |
| Apply with machine-local config | `make switch IMPURE=1` |
| Apply config (base only) | `make switch-base` |
| Validate without applying | `make check` |
| Format all Nix files | `make fmt` |
| Lint all Nix files | `make lint` |
| Update all inputs | `make update` |

### macOS (nix-darwin)

| Task | Command |
|------|---------|
| See what changed | `darwin-rebuild build --flake .#darwin && nix diff-closures /run/current-system ./result` |
| Rollback | `darwin-rebuild switch --rollback` |
| List generations | `darwin-rebuild --list-generations` |

### Linux / WSL (home-manager)

| Task | Command |
|------|---------|
| See what changed | `home-manager build --flake .#linux && nix diff-closures ~/.local/state/nix/profiles/home-manager ./result` |
| Rollback | `home-manager switch --flake .#linux -b backup` |
| List generations | `home-manager generations` |

## Inputs 📦

| Input | What it does |
|-------|-------------|
| [nixpkgs](https://github.com/NixOS/nixpkgs) (unstable) | Package repository. Rolling release, latest packages, CI-tested. |
| [nix-darwin](https://github.com/LnL7/nix-darwin) | Declarative macOS system configuration. |
| [home-manager](https://github.com/nix-community/home-manager) | Declarative user environment (dotfiles, packages, programs). |
| [agenix](https://github.com/ryantm/agenix) | Age-encrypted secrets management. |
| [nixvim](https://github.com/nix-community/nixvim) | Neovim configuration as typed Nix expressions. |

All inputs follow a single nixpkgs to avoid version drift. If an input ever breaks against nixpkgs-unstable (extremely rare), temporarily pin it to a specific rev — see CLAUDE.md for instructions.

## Manual setup 🔧✋

Some things can't be declared in Nix (yet). See [`docs/manual-setup.md`](docs/manual-setup.md) for post-deploy steps on new machines.

## License 📄

MIT
