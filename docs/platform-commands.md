# Platform-specific commands

Each platform has its own build tool with different commands for diffing, rollback, and generation management.

## macOS (nix-darwin)

| Task | Command |
|------|---------|
| See what changed | `darwin-rebuild build --flake .#darwin && nix diff-closures /run/current-system ./result` |
| Rollback | `darwin-rebuild switch --rollback` |
| List generations | `darwin-rebuild --list-generations` |

## NixOS-WSL (nixos-rebuild)

| Task | Command |
|------|---------|
| See what changed | `nixos-rebuild build --flake .#nixos-wsl && nix diff-closures /nix/var/nix/profiles/system ./result` |
| Rollback | `sudo nixos-rebuild switch --rollback` |
| List generations | `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system` |

## NixOS server / VPS (nixos-rebuild + disko)

| Task | Command |
|------|---------|
| First-time deploy | `nix run github:nix-community/nixos-anywhere -- --flake .#miles root@<ip>` |
| Update | `make deploy-miles MILES_HOST=root@<ip>` |
| See what changed | SSH in, then `nix diff-closures /nix/var/nix/profiles/system $(readlink -f /nix/var/nix/profiles/system)` |

## Linux / WSL (home-manager)

| Task | Command |
|------|---------|
| See what changed | `home-manager build --flake .#linux && nix diff-closures ~/.local/state/nix/profiles/home-manager ./result` |
| Rollback | `home-manager switch --flake .#linux -b backup` |
| List generations | `home-manager generations` |
