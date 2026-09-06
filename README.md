# nix-config

[![Check](https://github.com/tskovlund/nix-config/workflows/Check/badge.svg)](https://github.com/tskovlund/nix-config/actions/workflows/check.yml)
[![CodeQL](https://github.com/tskovlund/nix-config/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/tskovlund/nix-config/actions/workflows/codeql.yml)
[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Nix Flakes](https://img.shields.io/badge/Nix-Flakes-blue?logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Fully declarative, cross-platform environment — shell, editor, git, CLI tools, system preferences, secrets, apps — all defined as code. This is a [template repo](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository): hit **Use this template**, swap in your identity, deploy. One command reproduces the entire setup on a new machine.

- **macOS** — nix-darwin + home-manager (system + user config)
- **Linux / WSL** — standalone home-manager (user config)
- **NixOS-WSL** — nixos-rebuild + home-manager (full system)
- **NixOS server** — nixos-rebuild + disko for cloud VPS / bare-metal deployment

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/tskovlund/nix-config/main/bootstrap.sh | bash
```

The script installs Nix and Homebrew if needed, detects your platform, sets up identity, and runs the first deploy. After bootstrap completes: `cd ~/repos/nix-config && make bootstrap` for GitHub CLI auth and SSH key upload.

> **Have an age key?** Copy it to `~/.config/agenix/age-key.txt` before running bootstrap so secrets decrypt on the first deploy.
>
> **NixOS-WSL?** Get git/curl first: `nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git nixpkgs#curl`, then run bootstrap.
>
> **Prefer manual control?** See [`docs/manual-setup.md`](docs/manual-setup.md).

## Highlights

- **[Starship](https://starship.rs/) prompt** with deterministic hash-colored hostname — each machine gets a unique, consistent color
- **Full [Neovim](https://neovim.io/)** via [nixvim](https://github.com/nix-community/nixvim) — LSP, completion, format-on-save, telescope, treesitter
- **Case-insensitive tab completion** and [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) out of the box
- **Touch ID for sudo** on macOS — no more typing passwords in the terminal
- **Opinionated CLI toolkit** — bat, delta, eza, zoxide, fzf, ripgrep, fd, and more
- **[direnv](https://github.com/direnv/direnv) + [nix-direnv](https://github.com/nix-community/nix-direnv)** — automatic per-project dev environments
- **[agenix](https://github.com/ryantm/agenix) secrets** — age-encrypted, decrypted on deploy
- **Forkable identity** — zero personal info in the repo; your identity comes from a separate flake

See [`docs/features.md`](docs/features.md) for the full inventory.

## Targets and profiles

Every deployment is a **target** — a build tool + profile combination. **Base** gives you a solid dev environment on any machine. **Personal** layers on secrets, SSH keys, and personal config from your own flake.

| Target           | Manages                             | Profile  |
| ---------------- | ----------------------------------- | -------- |
| `darwin`         | macOS system + user config          | personal |
| `darwin-base`    | macOS system + user config          | base     |
| `nixos-wsl`      | NixOS-WSL system + user config      | personal |
| `nixos-wsl-base` | NixOS-WSL system + user config      | base     |
| `miles`          | Hetzner VPS system + user config    | personal |
| `linux`          | User config only (any Linux distro) | personal |
| `linux-base`     | User config only (any Linux distro) | base     |

`make switch` auto-detects the right target. `make switch-base` picks the base variant.

## Personal identity

This repo contains zero personal information. Your identity (username, name, email) comes from a separate **personal flake**:

```sh
mkdir -p ~/.config/nix-config
echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input
```

The personal flake exports `identity` (username, name, email) and `homeModules` (secrets, SSH keys, dotfiles). See [`docs/architecture.md`](docs/architecture.md) for the full design.

## Common tasks

| Task                            | Command                                  |
| ------------------------------- | ---------------------------------------- |
| Apply config (base + personal)  | `make switch`                            |
| Apply config (base only)        | `make switch-base`                       |
| Apply with machine-local config | `make switch IMPURE=1`                   |
| Deploy to VPS                   | `make deploy-miles MILES_HOST=root@<ip>` |
| Validate without applying       | `make check`                             |
| Update all inputs               | `make update`                            |
| Format Nix files                | `make fmt`                               |
| Lint Nix files                  | `make lint`                              |

All packages are pinned via `flake.lock`. Roll back with `git checkout flake.lock && make switch`. For platform-specific commands (rollback, diff closures, generations), see [`docs/platform-commands.md`](docs/platform-commands.md).

## Inputs

| Input                                                         | What it provides                                                           |
| ------------------------------------------------------------- | -------------------------------------------------------------------------- |
| [nixpkgs](https://github.com/NixOS/nixpkgs) (unstable)        | Packages — rolling release, CI-tested                                      |
| [nix-darwin](https://github.com/LnL7/nix-darwin)              | Declarative macOS system config                                            |
| [home-manager](https://github.com/nix-community/home-manager) | Declarative user environment                                               |
| [agenix](https://github.com/ryantm/agenix)                    | Age-encrypted secrets                                                      |
| [nixvim](https://github.com/nix-community/nixvim)             | Neovim config as typed Nix                                                 |
| [nixos-wsl](https://github.com/nix-community/NixOS-WSL)       | NixOS on WSL integration                                                   |
| [disko](https://github.com/nix-community/disko)               | Declarative disk partitioning                                              |
| nixpkgs-cuda (pinned rev)                                     | ollama-cuda for the WSL host, bumped deliberately (unfree, hours to build) |
| personal (stub)                                               | Your identity flake — see [Personal identity](#personal-identity)          |

All inputs follow a single nixpkgs to avoid version drift, except `nixpkgs-cuda`, which is pinned so a routine bump never triggers the CUDA compile.

## Documentation

| Document                                                 | Contents                                                                            |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [`docs/features.md`](docs/features.md)                   | Full feature inventory (shell, editor, git, CLI tools, macOS defaults, Claude Code) |
| [`docs/architecture.md`](docs/architecture.md)           | Targets, profiles, builders, system modules, adding new hosts                       |
| [`docs/manual-setup.md`](docs/manual-setup.md)           | Post-deploy manual steps (fonts, permissions, MCP registration)                     |
| [`docs/platform-commands.md`](docs/platform-commands.md) | Platform-specific commands (rollback, diff closures, generations)                   |
| [`docs/miles.md`](docs/miles.md)                         | Operational runbook for the Hetzner VPS                                             |

## Development

After deploying (which installs direnv), enter the dev shell:

```sh
cd ~/repos/nix-config
direnv allow
```

This sets up commit hooks — pre-commit formats and lints `.nix` files, pre-push runs `nix flake check --all-systems`. CI validates both Linux and macOS on every PR.

## Author

Thomas Skovlund Hansen — [skovlund.dev](https://skovlund.dev) · [thomas@skovlund.dev](mailto:thomas@skovlund.dev)

## License

[MIT](LICENSE)
