# nix-config ❄️

Fully declarative, cross-platform environment using Nix flakes, nix-darwin, and home-manager.

## What this does

Everything about your environment — shell, editor, git, CLI tools, system preferences — is defined as code in this repo. Applying the config on a new machine reproduces the entire setup exactly 🏠

- **macOS**: nix-darwin manages system settings + home-manager manages user config
- **Linux / WSL**: standalone home-manager manages user config

## Profiles 🧩

The config is split into two composable layers:

- **base** (`home/default.nix`) — dev environment essentials: shell, editor, git, CLI tools. Everything you'd want on any dev machine, including a work laptop.
- **personal** (`home/personal.nix`) — personal additions layered on top of base. Personal aliases, fun tools, personal SSH hosts, etc.

Each platform has two targets:

| Target | What it includes | Use case |
|--------|-----------------|----------|
| `darwin` / `linux` | base + personal | Personal machines |
| `darwin-base` / `linux-base` | base only | Shared or work machines |

## Prerequisites 📋

1. **Install Nix** — we recommend the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

   This installs Nix with flakes and the `nix` command enabled by default. If you use the [official installer](https://nixos.org/download/) instead, you'll need to enable `experimental-features = nix-command flakes` in `~/.config/nix/nix.conf`.

2. **Clone this repo**:

   ```sh
   git clone https://github.com/tskovlund/nix-config.git ~/repos/nix-config
   cd ~/repos/nix-config
   ```

3. **Personalize** — edit the `username` variable at the top of `flake.nix`:

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

### Subsequent deploys (macOS or Linux)

The Makefile auto-detects your platform:

```sh
make switch         # base + personal
make switch-base    # base only
```

### Linux / WSL (first time)

If `home-manager` isn't on your PATH yet, bootstrap it:

```sh
nix run home-manager -- switch --flake .#linux
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
│   ├── darwin/default.nix       # macOS system config (nix-darwin)
│   └── linux/default.nix        # Linux system config (placeholder)
│
├── home/
│   ├── default.nix              # Base dev environment (always imported)
│   ├── personal.nix             # Personal additions (imported by non-base targets)
│   ├── shell/                   # Zsh, starship prompt, bat
│   ├── editor/                  # Neovim via nixvim (LSP, completion, themes)
│   ├── git/                     # Git, delta, gh CLI
│   └── tools/                   # CLI toolkit, direnv, fzf
│
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
- [TokyoNight](https://github.com/folke/tokyonight.nvim) theme (night) with 5 extra themes available via `<leader>ct` picker
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
| Apply config (base only) | `make switch-base` |
| Validate without applying | `make check` |
| Format all Nix files | `make fmt` |
| Lint all Nix files | `make lint` |
| Update all inputs | `make update` |
| See what changed | `darwin-rebuild build --flake .#darwin && nix diff-closures /run/current-system ./result` |
| Rollback | `darwin-rebuild switch --rollback` |
| List generations | `darwin-rebuild --list-generations` |

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
