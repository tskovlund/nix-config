# CLAUDE.md — nix-config conventions

This file documents how this repo is structured and how to extend it.

## Architecture

- **flake.nix**: Entry point. Declares inputs and wires up four targets:
  - `darwinConfigurations."darwin"` — macOS, base + personal
  - `darwinConfigurations."darwin-base"` — macOS, base only
  - `homeConfigurations."linux"` — Linux, base + personal
  - `homeConfigurations."linux-base"` — Linux, base only
- **hosts/**: Platform-specific *system* config (nix-darwin settings, not user config)
  - `nix.enable = false` in darwin config because Determinate Nix manages the Nix daemon. This means `nix.*` options are unavailable in nix-darwin — configure Nix settings via Determinate instead.
- **home/**: User environment modules managed by home-manager. This is where most config lives.
- **files/**: Raw config files that modules source or symlink (e.g., Neovim Lua files)

## Profiles: base vs personal

- **`home/default.nix`** — base dev environment. Everything that belongs on any dev machine (shell, editor, git, CLI tools). New modules go here by default.
- **`home/personal.nix`** — personal additions layered on top. Only for things that are clearly personal (personal SSH hosts, fun tools, personal aliases).

When adding new config, put it in base unless it's obviously personal. When in doubt, ask.

## Adding a new home-manager module

1. Create `home/<category>/default.nix`
2. Import it from `home/default.nix` (for base) or `home/personal.nix` (for personal):
   ```nix
   imports = [
     ./shell
     ./git
     # add new module here
   ];
   ```
3. Test with `make check`, then `make switch`

## Style preferences

- **Conventional commits.** All commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `type(scope): description`. Common types: `feat`, `fix`, `docs`, `chore`, `refactor`. Scope is optional (e.g., `feat(shell): add fzf integration`).
- **No ambiguous abbreviations.** Use explicit names: `makeDarwin` not `mkDarwin`, `homeModules` not `hm`. The Nix community loves `mk`-prefixed names (from `mkDerivation`) but we prefer clarity. Exception: don't rename things from upstream APIs (`lib.mkIf` stays as `lib.mkIf`).

## Module conventions

- Each module directory has a `default.nix` entry point
- Use `programs.<name>` and `home.file` over raw file writes when possible — home-manager options give you type checking and merging
- Platform-specific logic: use `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux` inside home modules
- Keep modules focused: one concern per directory (shell, git, editor, etc.)

## State versions — never change these

- `system.stateVersion = 5` in `hosts/darwin/default.nix`
- `home.stateVersion = "25.11"` in `home/default.nix`

These are compatibility markers, not package selectors. Changing them can trigger irreversible data migrations.

## Follows override — if an input breaks

All inputs follow a single nixpkgs. If home-manager or nix-darwin ever breaks against the current nixpkgs-unstable (extremely rare):

1. Check the input's repo for a compatible commit
2. Temporarily pin that input to a specific rev:
   ```nix
   home-manager.url = "github:nix-community/home-manager/<commit-sha>";
   ```
3. Remove `inputs.nixpkgs.follows = "nixpkgs"` for that input (let it use its own nixpkgs)
4. File an issue or wait for the fix, then revert to `follows`

## Commands

- `make switch` — apply base + personal config (macOS)
- `make switch-base` — apply base only config (macOS)
- `make check` — validate flake
- `make update` — update all inputs
- `nix repl --file flake.nix` — explore the flake interactively

## Secrets

Secrets use agenix (age-encrypted). Never commit plaintext secrets, API keys, or private SSH keys. The `secrets/` directory will contain `.age` files only.
