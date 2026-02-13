# nix-config ❄️

Fully declarative, cross-platform environment — shell, editor, git, CLI tools, system preferences, secrets, apps — all defined as code.

This is a [template repo](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository). Hit **Use this template**, swap in your identity, deploy. Or fork it and make it yours. One command reproduces the entire setup on a new machine.

- **macOS** — system settings + user config via nix-darwin and home-manager
- **NixOS** — full system + user config via nixos-rebuild and home-manager
- **Linux** — user config via standalone home-manager (works on any distro, including WSL)

## Quick start 🚀

```sh
# macOS, Linux, or NixOS — the script detects your platform
curl -fsSL https://raw.githubusercontent.com/tskovlund/nix-config/main/bootstrap.sh | bash
```

The script installs what's needed (Nix, Homebrew on macOS — skips what's already present), walks you through profile selection and identity setup, generates an age key for secrets, and runs the first deploy. After it finishes:

```sh
cd ~/repos/nix-config
make bootstrap    # GitHub CLI auth, Claude Code settings, SSH key upload, cleanup
```

> **Prefer to review first?** `curl -fsSL ... -o bootstrap.sh && less bootstrap.sh && bash bootstrap.sh`
>
> **Want full manual control?** See [Manual setup](#manual-setup) below.

## Highlights ✨

- **[Starship](https://starship.rs/) prompt** with deterministic hash-colored hostname and username — each machine gets a unique, consistent color so you always know where you are
- **Full-fledged [Neovim](https://neovim.io/)** via [nixvim](https://github.com/nix-community/nixvim) — LSP, completion, format-on-save, telescope, treesitter, and more ([details below](#editor))
- **Case-insensitive tab completion** and [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) out of the box
- **Touch ID for sudo** — no more typing passwords in the terminal
- **Opinionated CLI toolkit** — [bat](https://github.com/sharkdp/bat) as cat/man pager, [delta](https://github.com/dandavison/delta) for diffs, [eza](https://github.com/eza-community/eza) for ls, [zoxide](https://github.com/ajeetdsouza/zoxide) for cd, [fzf](https://github.com/junegunn/fzf) for everything else
- **[direnv](https://github.com/direnv/direnv) + [nix-direnv](https://github.com/nix-community/nix-direnv)** — automatic per-project dev environments
- ...and a lot more. See [What's included](#whats-included-) for the full list.

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

## Targets and profiles 🧩

Every deployment is a **target** — a specific combination of build tool and profile:

| Target | Manages | Profile |
|--------|---------|---------|
| `darwin` | macOS system + user config | personal |
| `darwin-base` | macOS system + user config | base |
| `nixos-wsl` | NixOS-WSL system + user config | personal |
| `nixos-wsl-base` | NixOS-WSL system + user config | base |
| `linux` | User config only (any Linux distro) | personal |
| `linux-base` | User config only (any Linux distro) | base |

**Profiles** control what gets included:
- **base** — shell, editor, git, CLI tools, SSH client. Everything you'd want on any machine, including a work laptop.
- **personal** — base + personal additions, secrets, SSH keys, and modules from your private identity flake.

`make switch` auto-detects the right target. `make switch-base` picks the base variant.

> **How it all fits together** — builders, system modules, composition patterns, adding new hosts — is documented in [`docs/architecture.md`](docs/architecture.md).

## Personal identity 🔑

This repo contains zero personal information. Your identity (username, name, email) comes from a separate **personal flake** that you control.

On real machines, the Makefile reads `~/.config/nix-config/personal-input` and overrides the default stub:

```sh
mkdir -p ~/.config/nix-config
echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input
```

You can also pass it directly: `make switch PERSONAL_INPUT=path:$HOME/repos/nix-config-personal`

> **Note:** On macOS, `make switch` runs under `sudo`. If SSH-based fetching fails (root can't access your SSH agent), use a local checkout path instead.

### Creating your personal flake

Your personal flake needs a `flake.nix` that exports `identity` and `homeModules`:

```nix
{
  description = "Personal identity for nix-config";

  outputs = { ... }: {
    identity = {
      isStub = false;
      username = "your-username";   # system user, home directory
      fullName = "Your Full Name";  # git author name
      email = "you@example.com";    # git author email
    };

    # Home-manager modules for secrets, SSH, personal dotfiles.
    # Start with an empty list — add modules as you need them.
    homeModules = [ ];
  };
}
```

### Why a separate repo?

- **Forkable** — use this template, create your own identity flake, deploy. No grep-and-replace.
- **Private** — your identity repo can be private while nix-config stays public.
- **Per-machine** — different machines can point to different identity flakes (personal vs work).
- **Extensible** — export `homeModules` for secrets, SSH keys, and personal dotfiles.

## Machine-local config 🔧

For machine-specific packages that don't belong in the repo (work SDKs, vendor CLIs, experimental tools):

```nix
-- ~/.config/nix-config/local.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dotnet-sdk_8
    azure-cli
  ];
}
```

Apply with `make switch IMPURE=1`. Without `IMPURE=1`, the file is silently ignored (pure evaluation can't read paths outside the Nix store). See [`examples/local.nix`](examples/local.nix) for a starter template.

## Manual setup

> If you used `bootstrap.sh`, everything below is already done — skip to [Common tasks](#common-tasks-).

For full manual control instead of the bootstrap script:

1. **Install Nix** — we recommend the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

   On NixOS, skip this step. If you use the [official installer](https://nixos.org/download/), enable `experimental-features = nix-command flakes` in `~/.config/nix/nix.conf`.

2. **macOS only: Install Homebrew** — https://brew.sh. Also sign into the Mac App Store before deploying.

3. **Clone and configure identity:**

   ```sh
   git clone https://github.com/tskovlund/nix-config.git
   cd nix-config
   mkdir -p ~/.config/nix-config
   echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input
   ```

4. **First deploy:**

   ```sh
   # macOS
   nix build .#darwinConfigurations.darwin.system \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal
   sudo ./result/sw/bin/darwin-rebuild switch --flake .#darwin \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal

   # NixOS / NixOS-WSL
   sudo nixos-rebuild switch --flake .#nixos-wsl \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal

   # Linux / WSL (any distro)
   nix run home-manager -- switch --flake .#linux \
     --override-input personal git+ssh://git@github.com/YOUR_USER/nix-config-personal
   ```

   If `/etc/zshenv` conflicts on macOS: `sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin`

5. **Post-deploy:** `make bootstrap` for GitHub CLI auth, Claude Code settings, SSH key upload, and cleanup.

---

## Common tasks 🔧

| Task | Command |
|------|---------|
| Apply config (personal) | `make switch` |
| Apply config (base only) | `make switch-base` |
| Apply with local overrides | `make switch IMPURE=1` |
| Post-deploy setup | `make bootstrap` |
| Validate without applying | `make check` |
| Format Nix files | `make fmt` |
| Lint Nix files | `make lint` |
| Update all inputs | `make update` |

### Updating dependencies

All packages are pinned via `flake.lock`. To update:

```sh
make update    # update flake.lock to latest everything
make switch    # apply
```

No `apt upgrade` or `brew update`. The lock file is the single source of truth. Roll back with `git checkout flake.lock && make switch`.

For granular control: `nix flake update nixpkgs` or `nix flake update nixpkgs home-manager`.

### Platform-specific commands

<details>
<summary><strong>macOS (nix-darwin)</strong></summary>

| Task | Command |
|------|---------|
| See what changed | `darwin-rebuild build --flake .#darwin && nix diff-closures /run/current-system ./result` |
| Rollback | `darwin-rebuild switch --rollback` |
| List generations | `darwin-rebuild --list-generations` |

</details>

<details>
<summary><strong>NixOS-WSL (nixos-rebuild)</strong></summary>

| Task | Command |
|------|---------|
| See what changed | `nixos-rebuild build --flake .#nixos-wsl && nix diff-closures /nix/var/nix/profiles/system ./result` |
| Rollback | `sudo nixos-rebuild switch --rollback` |
| List generations | `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system` |

</details>

<details>
<summary><strong>Linux / WSL (home-manager)</strong></summary>

| Task | Command |
|------|---------|
| See what changed | `home-manager build --flake .#linux && nix diff-closures ~/.local/state/nix/profiles/home-manager ./result` |
| Rollback | `home-manager switch --flake .#linux -b backup` |
| List generations | `home-manager generations` |

</details>

## Repo structure 📁

```
nix-config/
├── flake.nix                    # Entry point: inputs, targets, builder functions
├── flake.lock                   # Pinned dependency versions
├── Makefile                     # make switch, make check, etc.
├── bootstrap.sh                 # New-machine bootstrap (curl-pipeable)
│
├── hosts/                       # System-level config (nix-darwin / NixOS modules)
│   ├── darwin/                  # macOS system (fonts, casks, defaults, Touch ID)
│   ├── nixos/                   # Shared NixOS layer (user setup, flakes, zsh)
│   ├── wsl/                     # WSL layer (interop, automount)
│   └── nixos-wsl/               # NixOS-WSL entry point (imports wsl/)
│
├── home/                        # User config (home-manager modules)
│   ├── default.nix              # Base profile entry point
│   ├── personal.nix             # Personal profile entry point
│   ├── shell/                   # Zsh, starship, bat
│   ├── editor/                  # Neovim via nixvim
│   ├── git/                     # Git, delta, gh CLI
│   ├── ssh/                     # SSH client (AddKeysToAgent)
│   ├── tools/                   # CLI toolkit, direnv, fzf
│   ├── claude/                  # Claude Code + statusline
│   ├── darwin/                  # macOS-only (Homebrew PATH, Keychain SSH)
│   └── nixos/                   # NixOS-only (systemd user services)
│
├── stubs/personal/              # Placeholder identity for CI
├── scripts/post-bootstrap.sh    # Post-deploy setup (make bootstrap)
├── docs/                        # Architecture docs, manual setup steps
├── examples/                    # Templates (local.nix)
├── files/                       # Raw config files sourced by modules
├── .githooks/                   # Commit hooks (format, lint, check)
└── .envrc                       # direnv → auto-enters dev shell
```

## Development 🛠️

After deploying (which installs direnv), enter the dev shell:

```sh
cd ~/repos/nix-config
direnv allow
```

This sets up commit hooks — pre-commit formats and lints `.nix` files, pre-push runs `nix flake check --all-systems`. CI validates both Linux and macOS on every PR.

## Inputs 📦

| Input | What it provides |
|-------|-----------------|
| [nixpkgs](https://github.com/NixOS/nixpkgs) (unstable) | Packages — rolling release, CI-tested |
| [nix-darwin](https://github.com/LnL7/nix-darwin) | Declarative macOS system config |
| [home-manager](https://github.com/nix-community/home-manager) | Declarative user environment |
| [agenix](https://github.com/ryantm/agenix) | Age-encrypted secrets |
| [nixvim](https://github.com/nix-community/nixvim) | Neovim config as typed Nix |
| [nixos-wsl](https://github.com/nix-community/NixOS-WSL) | NixOS on WSL integration |
| [mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix) | MCP servers (persistent memory) |
| personal (stub) | Your identity flake — see [Personal identity](#personal-identity-) |

All inputs follow a single nixpkgs to avoid version drift.

## Post-deploy manual steps 🔧✋

Almost everything is automated. `make bootstrap` prints a checklist of the few remaining manual steps at the end (font selection, permissions). For reference, they're also documented in [`docs/manual-setup.md`](docs/manual-setup.md).

## License 📄

MIT
