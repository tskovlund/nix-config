---
name: switch-verify
description: >
  Deploy and verify nix-config changes. Use after making changes to any
  nix-config module, when the user says "deploy", "switch", "apply changes",
  or "test the config". Handles make check, make switch, and visual
  verification for UI changes.
allowed-tools: Bash(make check), Bash(make switch *), Bash(make switch), Bash(make fmt), Bash(make lint), Bash(ls *), Bash(echo *)
---

# Deploy and verify

## Standard workflow

### 1. Pre-flight validation
```sh
make check
```
This runs `nix flake check --all-systems` — catches eval errors, type mismatches, and build failures across all platforms before deploying.

### 2. Deploy
```sh
make switch
```
Auto-detects the current platform (macOS / Linux / NixOS-WSL) and applies the config.

### 3. Verify

**Non-visual changes** (packages, env vars, aliases, services):
- Verify the change took effect (e.g., `which <tool>`, `echo $VAR`, test the alias)
- If everything works, commit

**Visual changes** (shell prompts, themes, TUI config, statusline, editor appearance):
- Describe what changed and what to look for
- Ask Thomas to verify the result visually before committing
- `make check` passing does NOT mean visual changes look correct

## Variants

### Testing local personal flake changes
```sh
make switch PERSONAL_INPUT=path:$HOME/repos/nix-config-personal
```
Uses the local checkout of nix-config-personal instead of the remote input.

### Testing with machine-local config
```sh
make switch IMPURE=1
```
Includes `~/.config/nix-config/local.nix` if it exists.

### Bypassing input cache
```sh
make switch REFRESH=1
```
Useful after pushing to the personal flake remote — forces Nix to re-fetch.

### Combining flags
```sh
make switch PERSONAL_INPUT=path:$HOME/repos/nix-config-personal IMPURE=1
```

## Troubleshooting

If `make check` or `make switch` fails, use `/nix-debug` for debugging strategies (eval errors, build failures, flake issues).

## Rollback

Nix config is declarative — to roll back, just fix the issue and re-switch. No manual rollback commands needed.

## Pre-commit note

Git commands that trigger hooks require dev shell tools. If not already in the dev shell:
```sh
nix develop --command git commit -m "message"
```
