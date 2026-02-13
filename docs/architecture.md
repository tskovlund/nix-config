# Architecture

This document explains how nix-config is put together — how targets, profiles, and system modules compose into deployable configurations. Read this when you're ready to extend the config or add a new host.

## Terminology

These are the only terms you need:

- **Target** — a concrete flake output you deploy with `make switch`. Example: `darwin`, `linux-base`, `nixos-wsl`. Each target combines a build tool and a profile.
- **Profile** — the level of config a target includes: **base** (essentials for any dev machine) or **personal** (base + your personal additions, secrets, and identity-specific config).
- **Build tool** — how the target gets deployed: `darwin-rebuild` (macOS), `nixos-rebuild` (NixOS), or `home-manager` (Linux — any distro).

Everything else — helpers, host modules, home modules — is internal wiring described below.

## Targets

The flake defines 6 targets:

| Target | Build tool | Profile | What it manages |
|--------|-----------|---------|----------------|
| `darwin` | `darwin-rebuild` | personal | macOS system + user config |
| `darwin-base` | `darwin-rebuild` | base | macOS system + user config |
| `nixos-wsl` | `nixos-rebuild` | personal | NixOS system + user config |
| `nixos-wsl-base` | `nixos-rebuild` | base | NixOS system + user config |
| `linux` | `home-manager` | personal | User config only (any Linux distro) |
| `linux-base` | `home-manager` | base | User config only (any Linux distro) |

**macOS** and **NixOS** targets manage both system-level settings and user config. **Linux** targets manage user config only — there's no system-level management, which is why they work on any Linux distro (Ubuntu, Fedora, WSL, etc.) without modification.

`make switch` auto-detects which target to use based on your OS. You can also use explicit targets: `make switch-darwin`, `make switch-linux`, `make switch-nixos-wsl`.

## Profiles

User config lives in `home/` as home-manager modules, split into two composable layers:

- **base** (`home/default.nix`) — everything you'd want on any dev machine: shell, editor, git, CLI tools, SSH client. Safe for work laptops.
- **personal** (`home/personal.nix`) — additions layered on top of base: personal aliases, fun tools, etc.

The personal flake can also export `homeModules` — additional home-manager modules (from your private repo) for secrets, SSH keys, and personal dotfiles.

Personal targets import both layers. Base targets import only the base layer. This is how the same repo serves both personal and work machines.

## How targets are built

Three builder functions in `flake.nix` wire targets together:

```
                          flake.nix
                             │
               ┌─────────────┼─────────────┐
               ▼             ▼              ▼
          makeDarwin     makeNixOS      makeLinux
               │             │              │
    ┌──────────┤           ┌─┤           returns
    ▼          ▼           ▼  ▼        homeManager
  system      user      system  user   Configuration
  config      config    config  config
```

### makeDarwin

Creates a nix-darwin system configuration. Always imports:
- `hosts/darwin/default.nix` — system config (Nix settings, fonts, Homebrew casks, macOS defaults)
- `home/darwin/` — macOS-specific home-manager config (Homebrew PATH, SSH Keychain)
- Profile modules (base or personal)
- nixvim and agenix home-manager modules
- Machine-local config (`local.nix`, when `--impure`)

Personal target also imports `hosts/darwin/personal.nix` (personal casks, Mac App Store apps).

### makeNixOS

Creates a NixOS system configuration. Always imports:
- `hosts/nixos/default.nix` — shared NixOS layer (user creation, flakes, zsh, home-manager integration)
- `home/nixos/` — NixOS-specific home-manager config (systemd user service workaround)
- Profile modules (base or personal)
- nixvim and agenix home-manager modules
- Machine-local config (`local.nix`, when `--impure`)

Host-specific modules are passed via the `nixosModules` parameter. For example, the `nixos-wsl` target passes `hosts/nixos-wsl/default.nix`.

### makeLinux

Creates a standalone home-manager configuration. No system-level config at all. Imports:
- Profile modules (base or personal)
- nixvim and agenix home-manager modules
- Machine-local config (`local.nix`, when `--impure`)

This is the simplest builder — no system management, no platform-specific home modules. Works on any Linux distro where Nix is installed.

## System modules (`hosts/`)

System-level config lives in `hosts/`, organized as composable layers:

```
hosts/
├── darwin/
│   ├── default.nix       # macOS system config (always imported by makeDarwin)
│   └── personal.nix      # Personal casks + MAS apps (darwin target only)
├── nixos/
│   └── default.nix       # Shared NixOS layer (always imported by makeNixOS)
├── wsl/
│   └── default.nix       # WSL-specific config (interop, automount, start menu)
└── nixos-wsl/
    └── default.nix       # NixOS-WSL entry point (imports wsl/)
```

The key pattern: **builders auto-import shared layers, host entry points import specialized layers.**

- `makeDarwin` always imports `hosts/darwin/` — you don't pass it manually.
- `makeNixOS` always imports `hosts/nixos/` — host entry points should NOT import it again.
- `hosts/nixos-wsl/` only imports `hosts/wsl/` — it gets the NixOS layer for free from `makeNixOS`.

This prevents duplication and makes new hosts easy to add.

### Why `hosts/wsl/` is separate from `hosts/nixos/`

WSL config (Windows interop, automount, start menu launchers) is not NixOS-specific — it could be reused by other WSL-based distributions. Keeping it separate from the NixOS layer preserves that option.

## Platform-specific home modules

Some home-manager config is platform-specific and shouldn't live in the shared `home/` modules:

- **`home/darwin/`** — macOS-only: Homebrew PATH, fn-toggle app, SSH Keychain integration. Imported by `makeDarwin`.
- **`home/nixos/`** — NixOS-only: disables systemd user service management during activation (linger handles startup instead). Imported by `makeNixOS`.

Shared modules in `home/` stay platform-agnostic. If a small platform check is needed, `pkgs.stdenv.isDarwin` is acceptable. Growing platform-specific config should move to the dedicated platform module.

## Adding a new NixOS host

To add a VPS, Raspberry Pi, or bare-metal NixOS host:

1. Create `hosts/<hostname>/default.nix` with host-specific config (hardware, networking, services)
2. **Do not** import `hosts/nixos/` — `makeNixOS` handles that automatically
3. Add a target in `flake.nix`:
   ```nix
   nixosConfigurations."<hostname>" = makeNixOS {
     homeModules = personalModules ++ personalHomeModules;
     nixosModules = [ ./hosts/<hostname> ];
   };
   ```
4. Apply: `sudo nixos-rebuild switch --flake .#<hostname>`

For non-WSL hosts, you must configure authentication in the host-specific config (e.g. `users.users.${username}.initialPassword` or `openssh.authorizedKeys.keys`). The NixOS builder does not set a password or SSH keys.

## Personal identity

The flake has a `personal` input that defaults to `stubs/personal/` — a placeholder with dummy values. On real machines, `make switch` overrides it with your actual personal flake via `--override-input`.

The personal flake exports:
- `identity` — `{ isStub, username, fullName, email }` used by `flake.nix` (username → system user) and `home/git/` (name, email → git config)
- `homeModules` — list of home-manager modules imported by personal targets (secrets, SSH, dotfiles)

CI uses the stub (no override needed). The stub exports `homeModules = []` so base targets evaluate cleanly.

## Machine-local config

An optional file at `~/.config/nix-config/local.nix` is imported by all targets when `--impure` is used. It's a standard home-manager module for machine-specific packages that don't belong in the repo. Without `--impure`, it's silently skipped.

## Secrets and SSH

See the [Secrets and SSH section in CLAUDE.md](../CLAUDE.md#secrets-and-ssh) for details on the agenix architecture, SSH key naming conventions, and how to add new secrets.
