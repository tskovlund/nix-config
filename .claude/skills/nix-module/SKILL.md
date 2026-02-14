---
name: nix-module
description: >
  Guide for adding a new home-manager module to nix-config. Use when creating
  a new module directory under home/, adding a new program or tool to the
  config, or when the user says "add a module" or "create a new module".
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(make check), Bash(make switch), Bash(make switch *)
---

# Adding a new home-manager module

## Steps

1. **Create the module directory and entry point:**
   - Path: `home/<category>/default.nix`
   - One concern per directory (shell, git, editor, etc.)

2. **Choose where to import it:**
   - `home/default.nix` — base dev environment (default, for anything useful on any dev machine)
   - `home/personal.nix` — personal additions (only for clearly personal things)
   - When in doubt, use base (`home/default.nix`)

3. **Add the import:**
   ```nix
   imports = [
     ./shell
     ./git
     ./tools
     # ...existing imports...
     ./<new-module>
   ];
   ```

4. **Write the module:**
   - Use `programs.<name>` and `home.packages` over raw file writes — home-manager options give type checking and merging
   - Raw config files go in `files/<category>/` and are sourced via `home.file`
   - Module args: `{ pkgs, config, lib, ... }:` — add `identity` only if needed

5. **Platform-specific config:**
   - Use dedicated platform modules (`home/darwin/`, `home/nixos/`) for growing platform-specific config
   - Small one-off checks with `pkgs.stdenv.isDarwin` are acceptable
   - Platform modules are wired via `darwinHomeModules` / `nixosHomeModules` in `flake.nix`

6. **Test and deploy:**
   - `make check` — validate flake (all platforms)
   - `make switch` — apply and verify

## Module template

```nix
{ pkgs, ... }:

{
  programs.<name> = {
    enable = true;
    # configuration options here
  };
}
```

Or for package-only modules:

```nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    <package>
  ];
}
```

## Conventions

- No ambiguous abbreviations: `makeDarwin` not `mkDarwin` (except upstream APIs like `lib.mkIf`)
- Keep modules focused: one concern per directory
- State versions must never be changed (see CLAUDE.md)
