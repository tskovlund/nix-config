---
name: nix-debug
description: >
  Nix debugging strategies and common fixes. Use when encountering Nix
  evaluation errors, build failures, flake lock issues, infinite recursion,
  hash mismatches, or when the user asks to debug a Nix problem. Also useful
  for nix repl tricks and home-manager troubleshooting.
allowed-tools: Read, Glob, Grep, Bash(nix *), Bash(home-manager *), Bash(make check), Bash(make switch *), Bash(darwin-rebuild *), Bash(nixos-rebuild *)
---

# Nix debugging

## Strategy

1. Read the error message carefully — Nix errors are verbose but informative
2. Determine if the issue is **eval-time** (Nix language) or **build-time** (derivation)
3. Use `--show-trace` for full stack traces: `make check 2>&1` or add `--show-trace` to rebuild commands

## Common eval errors

### Infinite recursion
- **Cause:** Circular imports or self-referencing attribute sets
- **Fix:** Check module imports for cycles. Use `lib.mkIf` / `lib.mkMerge` to break dependency chains
- **Trace clue:** `error: infinite recursion encountered` with no useful stack — add `--show-trace`

### Missing attribute
- **Cause:** Typo in attribute name, wrong nixpkgs channel, or missing module import
- **Fix:** Check spelling, verify package exists with `nix search nixpkgs#<name>`, ensure module is imported
- **Trace clue:** `error: attribute '<name>' missing`

### Type mismatch
- **Cause:** Passing wrong type to a home-manager option (e.g., string where list expected)
- **Fix:** Check option type with `nix repl` or home-manager docs

## Common build failures

### Hash mismatch
- **Cause:** Upstream source changed, or fetcher hash is wrong
- **Fix:** Update the hash. Use `lib.fakeHash` or `""` to get the expected hash from the error

### Missing dependency
- **Cause:** `buildInputs` or `nativeBuildInputs` incomplete
- **Fix:** Add the missing dependency to the appropriate input list

### Platform-specific failures
- **Cause:** Package doesn't support current platform
- **Fix:** Use `lib.optionals pkgs.stdenv.isDarwin [...]` or platform modules

## Flake issues

### Lock out of date
```sh
nix flake update              # Update all inputs
nix flake lock --update-input <name>  # Update single input
```

### Input follows conflicts
- **Cause:** An input's nixpkgs version conflicts with the pinned one
- **Fix:** See "Follows override" in CLAUDE.md — temporarily pin or remove `follows`

### Eval cache stale
```sh
make switch REFRESH=1         # Bypass Nix's input cache
```

## nix repl tricks

```sh
nix repl --file flake.nix     # Load the flake
```

Inside repl:
- Tab completion to explore attributes
- `:p <expr>` — pretty-print a value
- `:t <expr>` — show type
- `darwinConfigurations.darwin.config.home-manager.users.<user>` — inspect home-manager config
- `builtins.attrNames <set>` — list attribute names

## home-manager specifics

```sh
home-manager generations       # List generations with timestamps
home-manager packages          # List installed packages
```

To see what changed between generations, compare the generation paths.

## Nix store

```sh
nix store gc                   # Garbage collect
nix store gc --max 5G          # Keep at least 5G free
nix store diff-closures /nix/store/<old> /nix/store/<new>  # Compare closures
nix path-info -rSh /run/current-system  # Show closure size
```

## This repo's commands

- `make check` — `nix flake check --all-systems` (validates all platforms)
- `make switch` — rebuild and activate (auto-detects platform)
- `make fmt` — format Nix files with nixfmt
- `make lint` — lint with statix + deadnix
