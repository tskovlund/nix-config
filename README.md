# nix-config ❄️

Fully declarative, cross-platform dev environment. One repo, one command, every machine identical.

Nix flakes + [nix-darwin](https://github.com/LnL7/nix-darwin) + [home-manager](https://github.com/nix-community/home-manager) — shell, editor, git, CLI tools, system preferences, secrets — all defined as code. Fork it, swap in your identity, deploy.

- **macOS** — nix-darwin + home-manager (system + user config)
- **Linux / WSL** — standalone home-manager (user config)
- **NixOS / NixOS-WSL** — nixos-rebuild + home-manager (full system)

## Quick start 🚀

```sh
# macOS / Linux / NixOS-WSL
curl -fsSL https://raw.githubusercontent.com/tskovlund/nix-config/main/bootstrap.sh | bash
```

The bootstrap script handles everything: installs Nix and Homebrew if needed (skips what's already present), detects your platform (macOS, Linux, NixOS-WSL), selects your profile, sets up identity, generates an age key for secrets, and runs the first deploy. On NixOS-WSL, it automatically handles the user migration when the bootstrap user differs from the target user. After it completes:

```sh
cd ~/repos/nix-config
make bootstrap    # GitHub CLI auth, Claude Code settings, cleanup
```

> **Existing secrets?** If you already have an age key from another machine, copy it to `~/.config/agenix/age-key.txt` before running bootstrap. Otherwise, the script generates a new one.
>
> **NixOS-WSL?** On a fresh NixOS-WSL install, get `git` and `curl` first: `nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git nixpkgs#curl`, then run bootstrap. The script detects NixOS-WSL automatically.
>
> **Prefer to review first?** `curl -fsSL ... -o bootstrap.sh && less bootstrap.sh && bash bootstrap.sh`
>
> **Prefer full manual control?** See [Manual setup](#manual-setup) in the setup guide below.

## Highlights ✨

- **[Starship](https://starship.rs/) prompt** with deterministic hash-colored hostname and username — each machine gets a unique, consistent color so you always know where you are
- **Full-fledged [Neovim](https://neovim.io/)** via [nixvim](https://github.com/nix-community/nixvim) — LSP, completion, format-on-save, telescope, treesitter, and more ([details below](#editor))
- **Case-insensitive tab completion** and [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) out of the box
- **Touch ID for sudo** — no more typing passwords in the terminal
- **Opinionated CLI toolkit** — [bat](https://github.com/sharkdp/bat) as cat/man pager, [delta](https://github.com/dandavison/delta) for diffs, [eza](https://github.com/eza-community/eza) for ls, [zoxide](https://github.com/ajeetdsouza/zoxide) for cd, [fzf](https://github.com/junegunn/fzf) for everything else
- **[direnv](https://github.com/direnv/direnv) + [nix-direnv](https://github.com/nix-community/nix-direnv)** — automatic per-project dev environments
- ...and a lot more. See [What's included](#whats-included-) for the full inventory.

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
- [gh](https://cli.github.com/) — GitHub CLI
- SSH commit signing (via personal flake) — verified commits on GitHub with your SSH key
- SSH protocol for all GitHub URLs (via personal flake) — transparent HTTPS-to-SSH rewrite

### SSH and secrets
- [agenix](https://github.com/ryantm/agenix) — age-encrypted secrets decrypted on `make switch`
- SSH client config with `AddKeysToAgent` and macOS Keychain integration
- SSH key management via personal flake (encrypted private keys, host routing)

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

### Claude Code
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — AI coding assistant CLI
- Custom statusline showing directory, git status, model, context usage, cost, and session info (aligned with starship prompt style)
- [MCP Memory Server](https://github.com/modelcontextprotocol/servers/tree/main/src/memory) — persistent knowledge graph across sessions (entities, relations, observations)

---

## Setup guide 📋

Everything below is for people who want to understand what the bootstrap does, set things up manually, or customize the config.

### Personal identity 🔑

This repo contains zero personal information. Your identity (username, name, email) comes from a separate **personal flake** that you control.

The flake has an input called `personal` that defaults to a placeholder stub. On real machines, you override it with your own personal flake via `~/.config/nix-config/personal-input`:

```sh
mkdir -p ~/.config/nix-config
echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input
```

When you run `make switch`, the Makefile reads this file and passes `--override-input personal <url>` to the rebuild command. Without it, `make switch` prints a clear error. You can also pass the override directly:

```sh
make switch PERSONAL_INPUT=path:/path/to/local-checkout
```

> **Note:** On macOS, `make switch` runs under `sudo`. If SSH-based fetching fails (root can't access your SSH agent), use a local checkout: `make switch PERSONAL_INPUT=path:$HOME/repos/nix-config-personal`

#### Creating your personal flake

Your personal flake needs a `flake.nix` that exports `identity` and `homeModules`:

```nix
{
  description = "Personal identity for nix-config";

  outputs = { ... }: {
    identity = {
      isStub = false;
      username = "your-username";
      fullName = "Your Full Name";
      email = "you@example.com";
    };

    # Home-manager modules for secrets, SSH, personal dotfiles.
    # Empty list if you don't have any yet.
    homeModules = [ ];
  };
}
```

| Field | What it controls |
|-------|-----------------|
| `username` | System user account, home directory path |
| `fullName` | Git commit author name |
| `email` | Git commit author email |
| `isStub` | Must be `false` in a real identity flake |

#### Why a separate repo?

- **Forkable** — fork nix-config, create your own personal flake, deploy. No grep-and-replace.
- **Safe to share** — secrets are age-encrypted (`.age` files), so the personal flake can be public. Private repos also work.
- **Per-machine** — different machines can point to different identity flakes (personal vs work).
- **Extensible** — the personal flake exports `homeModules` for secrets, SSH keys, and personal dotfiles.

### Machine-local config 🔧

For machine-specific packages that don't belong in the repo (work SDKs, vendor CLIs, experimental tools), create an optional local config file:

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

### Manual setup

If you prefer full control instead of `bootstrap.sh`:

1. **Install Nix** — we recommend the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

   On NixOS, Nix is already installed — skip this step. If you use the [official installer](https://nixos.org/download/) instead, enable `experimental-features = nix-command flakes` in `~/.config/nix/nix.conf`.

2. **macOS only: Install Homebrew** — https://brew.sh. nix-darwin manages what Homebrew installs (casks, Mac App Store apps), but Homebrew itself must be installed first. Also sign into the Mac App Store before deploying.

3. **Clone and configure identity:**

   ```sh
   git clone https://github.com/tskovlund/nix-config.git
   cd nix-config
   mkdir -p ~/.config/nix-config
   echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input
   ```

4. **Deploy:**

   **macOS:**
   ```sh
   nix build .#darwinConfigurations.darwin.system \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal
   sudo ./result/sw/bin/darwin-rebuild switch --flake .#darwin \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal
   ```

   **Linux / WSL:**
   ```sh
   nix run home-manager -- switch --flake .#linux \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal
   ```

   **NixOS / NixOS-WSL:**
   ```sh
   sudo nixos-rebuild switch --flake .#nixos-wsl \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal
   ```

   If `/etc/zshenv` conflicts on macOS: `sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin`

5. **Post-deploy:** Run `make bootstrap` for GitHub CLI auth, Claude Code settings, SSH key upload, and cleanup reminders.

### Subsequent deploys

The Makefile auto-detects your platform and reads the personal identity override from `~/.config/nix-config/personal-input`:

```sh
make switch         # base + personal
make switch-base    # base only
```

---

## Architecture 🧩

### Flake targets

The flake defines 6 deployable targets — one per platform/profile combination:

| Target | Platform | Profile | Build tool |
|--------|----------|---------|------------|
| `darwin` | macOS | base + personal | `darwin-rebuild` |
| `darwin-base` | macOS | base only | `darwin-rebuild` |
| `linux` | Linux / WSL | base + personal | `home-manager` |
| `linux-base` | Linux / WSL | base only | `home-manager` |
| `nixos-wsl` | NixOS-WSL | base + personal | `nixos-rebuild` |
| `nixos-wsl-base` | NixOS-WSL | base only | `nixos-rebuild` |

Use the full target for personal machines, base-only for shared or work machines. `make switch` auto-detects which target to use.

> **Why only `nixos-wsl` and not separate `nixos` / `wsl` targets?** Targets are concrete deployments, not layers. NixOS-WSL is the only NixOS host defined so far. Adding a VPS or Raspberry Pi would add new targets (e.g. `nixos-vps`), each composed from reusable host layers. See [Host layers](#host-layers) below.

### Profiles

User config lives in `home/` as home-manager modules, split into two composable layers:

- **base** (`home/default.nix`) — dev environment essentials: shell, editor, git, CLI tools. Everything you'd want on any dev machine, including a work laptop.
- **personal** (`home/personal.nix`) — personal additions layered on top of base. Personal aliases, fun tools, etc.

The personal flake can also export `homeModules` — additional home-manager modules for secrets, SSH keys, and personal dotfiles that live in the personal repo.

### How everything composes

```
                          flake.nix
                             │
               ┌─────────────┼─────────────┐
               ▼             ▼              ▼
          makeDarwin     makeLinux      makeNixOS
               │             │              │
    ┌──────────┤          returns         ┌─┤
    ▼          ▼       homeManager        ▼  ▼
hosts/darwin  home-     Configuration   hosts/  home-
              manager                   nixos   manager
              user ──►                    │     user ──►
              config   home/ modules    (auto)  config   home/ modules
                       + home/darwin/           + home/nixos/
                       + personalHome           + personalHome
                         Modules                  Modules
                       + local.nix              + local.nix
```

Three helpers in `flake.nix` wire targets together:

- **`makeDarwin`** — creates a nix-darwin system. Always imports `hosts/darwin/` for system config and `home/darwin/` for macOS-specific home-manager config (Homebrew PATH, Keychain SSH).
- **`makeLinux`** — creates a standalone home-manager configuration. No system-level config.
- **`makeNixOS`** — creates a NixOS system. Always imports `hosts/nixos/` (flakes, zsh, user setup) and `home/nixos/` (systemd workaround). Host-specific modules are passed via `nixosModules`.

Each helper also imports:
- The chosen profile modules (`baseModules` or `personalModules` + `personalHomeModules`)
- `nixvim` and `agenix` home-manager modules
- Machine-local config from `~/.config/nix-config/local.nix` (when `--impure` is used)

### Host layers

System-level config lives in `hosts/`, split into reusable layers that compose into targets:

| Directory | Purpose | Used by |
|-----------|---------|---------|
| `hosts/darwin/` | macOS system config (Nix settings, fonts, casks, system defaults) | `makeDarwin` (auto-imported) |
| `hosts/darwin/personal.nix` | Personal macOS casks + Mac App Store apps | `darwin` target only |
| `hosts/nixos/` | General NixOS layer (user setup, flakes, zsh) | `makeNixOS` (auto-imported) |
| `hosts/wsl/` | General WSL layer (interop, automount, start menu) | Imported by `hosts/nixos-wsl/` |
| `hosts/nixos-wsl/` | NixOS-WSL entry point — imports `hosts/wsl/` | `nixos-wsl` targets via `nixosModules` |

The key pattern: **helpers auto-import shared layers, host entry points import specialized layers.** So `makeNixOS` always includes `hosts/nixos/`, and `hosts/nixos-wsl/` only needs to import `hosts/wsl/` — it gets the NixOS layer for free. This prevents duplication and makes it easy to add new NixOS hosts.

The `hosts/wsl/` layer is separate because WSL config (interop, automount) is not NixOS-specific — it could be reused by other WSL distributions in the future.

### Platform home-manager modules

Some home-manager config is platform-specific:

- **`home/darwin/`** — macOS-only: Homebrew PATH, fn-toggle app, SSH Keychain integration
- **`home/nixos/`** — NixOS-only: disables systemd user service management during activation (linger handles startup instead)

These are wired into `makeDarwin` and `makeNixOS` respectively — shared modules in `home/` stay platform-agnostic.

### Adding a new NixOS host

To add a new NixOS host (VPS, bare-metal, Raspberry Pi):

1. Create `hosts/<hostname>/default.nix` with host-specific config (hardware, networking, services)
2. Do NOT import `hosts/nixos/` — `makeNixOS` handles that automatically
3. Add a `nixosConfigurations.<hostname>` entry in `flake.nix` using `makeNixOS`
4. Apply with `sudo nixos-rebuild switch --flake .#<hostname>`

> **Note:** For non-WSL NixOS hosts, you must configure authentication in the host-specific config (e.g. `users.users.${username}.initialPassword` or `openssh.authorizedKeys.keys`). The `makeNixOS` helper does not set a password or SSH keys — WSL handles this via the `nixos-wsl` module.

---

## Repo structure 📁

```
nix-config/
├── flake.nix                    # Entry point: inputs + all targets
├── flake.lock                   # Pinned dependency versions
├── Makefile                     # Convenience targets (make switch, etc.)
├── bootstrap.sh                 # New-machine bootstrap (curl-pipeable)
│
├── hosts/
│   ├── darwin/default.nix       # macOS base system config (nix-darwin, base casks, system defaults)
│   ├── darwin/personal.nix      # macOS personal casks + Mac App Store apps
│   ├── nixos/default.nix        # General NixOS layer (user setup, flakes, zsh, unfree config)
│   ├── wsl/default.nix          # General WSL layer (interop, automount, start menu)
│   ├── nixos-wsl/default.nix    # NixOS-WSL entry point (imports wsl layer; nixos layer added by makeNixOS)
│   └── [future: vps/, rpi/]     # Additional NixOS hosts
│
├── home/
│   ├── default.nix              # Base dev environment (always imported)
│   ├── personal.nix             # Personal additions (imported by non-base targets)
│   ├── darwin/                  # macOS-only home-manager config (Homebrew PATH, Keychain SSH)
│   ├── nixos/                   # NixOS-only home-manager config (systemd user services)
│   ├── shell/                   # Zsh, starship prompt, bat
│   ├── editor/                  # Neovim via nixvim (LSP, completion, themes)
│   ├── git/                     # Git, delta, gh CLI
│   ├── ssh/                     # SSH client config (AddKeysToAgent, host routing)
│   ├── tools/                   # CLI toolkit, direnv, fzf
│   └── claude/                  # Claude Code + statusline script
│
├── scripts/                     # Support scripts
│   └── post-bootstrap.sh        # Post-deploy initialization (make bootstrap)
├── stubs/personal/              # Placeholder identity for CI (overridden on real machines)
├── examples/                    # Templates (local.nix, etc.)
├── .githooks/                   # Repo-local git hooks (pre-push)
├── .envrc                       # direnv config (auto-enters dev shell)
└── files/                       # Raw config files sourced by modules
```

## Common tasks 🔧

| Task | Command |
|------|---------|
| Bootstrap a new machine | `bash bootstrap.sh` (or curl-pipe, see Quick start) |
| Post-deploy setup | `make bootstrap` |
| Apply config (base + personal) | `make switch` |
| Apply with machine-local config | `make switch IMPURE=1` |
| Force re-fetch all inputs | `make switch REFRESH=1` |
| Apply config (base only) | `make switch-base` |
| Validate without applying | `make check` |
| Format all Nix files | `make fmt` |
| Lint all Nix files | `make lint` |
| Update all inputs | `make update` |

### Updating dependencies

All packages and tools are pinned via `flake.lock`. To get newer versions (e.g. a newer Claude Code, updated Neovim plugins, security patches):

```sh
make update    # updates flake.lock to latest nixpkgs-unstable + all inputs
make switch    # applies the update
```

This is how you update everything — there's no `apt upgrade` or `brew update`. The flake lock is the single source of truth for dependency versions. If an update breaks something, roll back with `git checkout flake.lock && make switch`.

For granular control, update individual inputs:

```sh
nix flake update nixpkgs              # only update nixpkgs
nix flake update nixpkgs home-manager # update a subset
```

### Platform-specific commands

**macOS (nix-darwin):**

| Task | Command |
|------|---------|
| See what changed | `darwin-rebuild build --flake .#darwin && nix diff-closures /run/current-system ./result` |
| Rollback | `darwin-rebuild switch --rollback` |
| List generations | `darwin-rebuild --list-generations` |

**Linux / WSL (home-manager):**

| Task | Command |
|------|---------|
| See what changed | `home-manager build --flake .#linux && nix diff-closures ~/.local/state/nix/profiles/home-manager ./result` |
| Rollback | `home-manager switch --flake .#linux -b backup` |
| List generations | `home-manager generations` |

**NixOS-WSL (nixos-rebuild):**

| Task | Command |
|------|---------|
| See what changed | `nixos-rebuild build --flake .#nixos-wsl && nix diff-closures /nix/var/nix/profiles/system ./result` |
| Rollback | `sudo nixos-rebuild switch --rollback` |
| List generations | `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system` |

### Why `--flake .#darwin` instead of just `--flake .`?

nix-darwin auto-detects configs by matching your machine's hostname. We use generic config names (`darwin`, `linux`) so the repo works on any machine without renaming entries per host. The trade-off is one extra flag — the Makefile handles this for you.

## Development 🛠️

After deploying the config (which installs direnv), allow direnv to enter the dev shell:

```sh
cd ~/repos/nix-config
direnv allow
```

This automatically sets up commit hooks — pre-commit formats and lints `.nix` files, pre-push runs `nix flake check --all-systems`. If direnv isn't available yet (fresh clone before first deploy):

```sh
git config core.hooksPath .githooks
```

CI validates both Linux and macOS on every PR.

## Inputs 📦

| Input | What it does |
|-------|-------------|
| [nixpkgs](https://github.com/NixOS/nixpkgs) (unstable) | Package repository. Rolling release, latest packages, CI-tested. |
| [nix-darwin](https://github.com/LnL7/nix-darwin) | Declarative macOS system configuration. |
| [home-manager](https://github.com/nix-community/home-manager) | Declarative user environment (dotfiles, packages, programs). |
| [agenix](https://github.com/ryantm/agenix) | Age-encrypted secrets management. |
| [nixvim](https://github.com/nix-community/nixvim) | Neovim configuration as typed Nix expressions. |
| [nixos-wsl](https://github.com/nix-community/NixOS-WSL) | NixOS on WSL integration module. |
| [mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix) | Nix-packaged MCP servers (used for persistent memory). |
| personal (stub default) | Personal identity flake. Defaults to a placeholder stub; override with your own. See [Personal identity](#personal-identity-). |

All non-personal inputs follow a single nixpkgs to avoid version drift. If an input ever breaks against nixpkgs-unstable (extremely rare), temporarily pin it to a specific rev — see CLAUDE.md for instructions.

## Manual setup 🔧✋

Most post-deploy steps are automated by `bootstrap.sh` and `make bootstrap`. A few things still require manual intervention — see [`docs/manual-setup.md`](docs/manual-setup.md) for the remaining steps.

## License 📄

MIT
