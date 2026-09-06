# nix-config

This file documents how this repo is structured and how to extend it.

Follow the code standards in [CONVENTIONS.md](CONVENTIONS.md).

## Architecture

- **flake.nix**: Entry point. Declares inputs and wires up:
  - `darwinConfigurations."darwin"` / `."darwin-base"` — macOS, base + personal / base only
  - `homeConfigurations."linux"` / `."linux-base"` — Linux, base + personal / base only
  - `nixosConfigurations."nixos-wsl"` / `."nixos-wsl-base"` — NixOS-WSL, base + personal / base only
  - `nixosConfigurations."miles"` — Hetzner VPS (always personal — no base variant)
  - `devShells` — dev shell with commit hook setup (entered automatically via direnv)
- **hosts/**: Platform-specific _system_ config (nix-darwin / NixOS settings, not user config)
  - `hosts/darwin/default.nix` — base system config. `nix.enable = false` here because Determinate Nix manages the daemon, so `nix.*` options are unavailable in nix-darwin — configure Nix settings via Determinate instead.
  - `hosts/darwin/personal.nix` — personal casks, Mac App Store apps. Imported via `darwinModules` in the personal `makeDarwin` call.
  - `hosts/nixos/default.nix` — general NixOS layer, reusable by all NixOS hosts (WSL, VPS, bare-metal)
  - `hosts/wsl/default.nix` — general WSL layer, reusable for any WSL distribution
  - `hosts/nixos-wsl/default.nix` — NixOS-WSL entry point. Imports the wsl layer; nixos layer is auto-imported by makeNixOS.
  - `hosts/miles/` — Hetzner Cloud VPS (host naming convention: jazz legends). Split into `default.nix`, `disk-config.nix`, `observability.nix`, `backups.nix`, and `tailscale.nix`. See **docs/miles.md** for the operational runbook.
- **home/**: User environment modules managed by home-manager. This is where most config lives.
- **stubs/personal/**: Placeholder identity flake for CI. On real machines, `make switch` overrides this with the real personal flake via `~/.config/nix-config/personal-input`.
- **files/**: Raw config files that modules source or symlink
- **bootstrap.sh**: Curl-pipeable bootstrap for new machines. On NixOS-WSL, handles the two-phase build when the bootstrap user (e.g. `nixos`) differs from the target user — base first to create the user, then the full personal config.
- **scripts/**: Support scripts (not Nix modules)
- **.githooks/**: Repo-local git hooks (pre-commit formats/lints, pre-push runs `nix flake check --all-systems`)
- **.envrc**: direnv config — `use flake` to enter the dev shell, which sets `core.hooksPath`

## Personal identity

This repo contains no personal information. Identity comes from an external **personal flake** input (nix-config-personal).

- **`inputs.personal`** defaults to `path:./stubs/personal` — placeholder values, `isStub = true`.
- `make switch` reads `~/.config/nix-config/personal-input` and passes `--override-input personal <url>`. Without identity configured it prints a clear error.
- The personal flake exports `identity = { isStub, username, fullName, email }` (consumed by `flake.nix` and `home/git/default.nix`) and `homeModules` (imported via `personalHomeModules`).
- `username` flows from `identity.username` through all system/user config via closures. Home-manager modules receive `identity` via `extraSpecialArgs` — use `{ identity, ... }:` in the module args.
- CI uses the stub (no override); it passes because stub values are valid strings and `homeModules = []`.

## Profiles: base vs personal

The base/personal split applies at both layers:

- **home-manager**: `home/default.nix` (base dev environment — new modules go here by default) and `home/personal.nix` (clearly personal things only: personal SSH hosts, fun tools, personal aliases).
- **nix-darwin**: `hosts/darwin/default.nix` (base casks) and `hosts/darwin/personal.nix` (personal casks, Mac App Store apps).

When adding new config, put it in base unless it's obviously personal. When in doubt, ask.

## Git workflow

Small changes go direct to main; structural work goes branch + PR.

- Copilot auto-reviews every PR via the "Protect main" ruleset. Read its comments with
  `gh api repos/tskovlund/nix-config/pulls/<N>/comments`, fix or decline each one with a reply, and repeat until clean — a PR isn't ready for Thomas until CI passes and no automated comment is unresolved.
- The pre-push hook runs `nix flake check` on every push, including direct-to-main. CI additionally runs required checks for both Linux and macOS on PRs.
- After merge: `git fetch --prune`, close related GitHub issues, comment the PR link on the Linear issue and move it to Done.
- PR bodies follow `.github/PULL_REQUEST_TEMPLATE.md` (Summary / Test plan / Related issues). The test plan always includes `make check` and `make switch`.
- Repo owner can bypass force-push protection when needed (e.g. amending on a PR branch).

Update **README.md** and **AGENTS.md** whenever a change affects them — new modules, new tools, workflow changes, architectural decisions.

### Issue tracking

GitHub Issues is the implementation tracker for this repo; Linear handles higher-level planning. Use the templates in `.github/ISSUE_TEMPLATE/` (Enhancement, Bug, Research) — Research issues end with "Trigger to revisit" and deliberately have no acceptance criteria.

- **Acceptance criteria on every actionable issue** — explicit, verifiable conditions. That's how we know an issue is done.
- **Don't edit issue bodies — use comments.** The body is the original spec; corrections, findings, and retrospective context go in comments so the timeline is preserved. Exceptions: typos, adding missing template sections before work starts, ticking checkboxes.
- **Always read the comments before working an issue.** They hold scope changes and design decisions the body won't have.
- **Labels** (at least one per issue): `bug`, `enhancement`, `documentation`, `phase`, `ci`, `research`, `dependencies`, `github actions`. No milestones or GitHub Projects — `phase` is enough.

## Style preferences

- **Conventional commit scopes.** Include a scope when a commit touches a single module; omit for cross-cutting changes.
  - **Module scopes** (map to `home/<dir>/`): `shell`, `git`, `editor`, `tools`, `claude`, `darwin`, `linux`
  - **Infra scopes**: `ci`, `bootstrap`, `flake`, `deps`
  - Example: `feat(shell): add fzf integration`, `chore(deps): update flake inputs`
- **Nix naming: no `mk` prefix.** Use `makeDarwin` not `mkDarwin`, `homeModules` not `hm`. The Nix community loves `mk`-prefixed names (from `mkDerivation`) but we prefer clarity. Exception: don't rename things from upstream APIs (`lib.mkIf` stays as `lib.mkIf`).

## Module conventions

- Each module directory has a `default.nix` entry point
- Use `programs.<name>` and `home.file` over raw file writes when possible — home-manager options give you type checking and merging
- Keep modules focused: one concern per directory (shell, git, editor, etc.)
- **Platform-specific config:** Use dedicated platform modules (`home/darwin/`, `home/nixos/`) rather than `isDarwin`/`isLinux` conditionals in shared modules. These are wired into helpers in `flake.nix` via `darwinHomeModules` / `nixosHomeModules`. Small one-off checks with `pkgs.stdenv.isDarwin` are acceptable, but growing platform-specific config should move to the platform module.

## Machine-local config

Three mechanisms allow per-machine customization without modifying the repo. All live outside the repo, so `nix flake check` and CI are unaffected.

| File                                    | What it is                                              | Applies to         | How to apply           |
| --------------------------------------- | ------------------------------------------------------- | ------------------ | ---------------------- |
| `~/.config/nix-config/local.nix`        | home-manager module                                     | all targets        | `make switch IMPURE=1` |
| `~/.config/nix-config/local-system.nix` | NixOS module (`security.pki`, `networking`, `services`) | NixOS targets only | `make switch IMPURE=1` |
| `~/.ssh/config.local`                   | SSH config fragment                                     | all targets        | no `--impure` needed   |

The two Nix files are silently skipped without `--impure`; see `examples/` for starter templates. Work SDKs such as `dotnet-sdk_10` are deliberately not in the base profile — `examples/local.nix` carries them. `config.local` is `Include`d at the top of the generated `~/.ssh/config`, and SSH is first-match-wins, so its entries override the managed config (including the personal flake's GitHub host entry) — that's how a work machine overrides `Host github.com` with a work key.

## State versions — never change these

- `system.stateVersion = 5` in `hosts/darwin/default.nix`
- `system.stateVersion = "25.05"` in `hosts/nixos/default.nix`
- `home.stateVersion = "25.11"` in `home/default.nix`

These are compatibility markers, not package selectors. Changing them can trigger irreversible data migrations.

## Commands

- `bootstrap.sh` — new-machine bootstrap (installs Nix, clones, deploys)
- `make bootstrap` — post-deploy initialization (gh auth, Claude settings, manual step reminders)
- `make switch` — apply base + personal config (auto-detects macOS / Linux / NixOS-WSL)
- `make switch REFRESH=1` — same, but bypass Nix's input cache (useful after pushing to personal flake)
- `make switch-base` — apply base only config (auto-detects platform)
- `make switch-darwin` / `switch-darwin-base` — explicit macOS targets
- `make switch-linux` / `switch-linux-base` — explicit Linux (standalone home-manager) targets
- `make switch-nixos-wsl` / `switch-nixos-wsl-base` — explicit NixOS-WSL targets
- `make deploy-miles` — remote deployment to Hetzner VPS (builds on VPS). Requires dev shell (`nixos-rebuild` isn't in PATH on macOS): `nix develop --command make deploy-miles`
- `make check` — validate flake (all platforms)
- `make fmt` — format all Nix files with nixfmt
- `make lint` — lint all Nix files with statix + deadnix
- `make update` — update all inputs
- `nix repl --file flake.nix` — explore the flake interactively
- `c` / `claude` — run Claude Code normally
- `ct` / `claude-team` — macOS only (`home/darwin/`): launches Claude Code inside tmux -CC (iTerm2 control mode) so agent team splits render as native iTerm2 panes. Use for agent team sessions.

**Important:** Git commands that trigger hooks (commit, push) require dev shell tools (`nixfmt`, `statix`, `deadnix`). Prefix with `nix develop --command` if not already in the dev shell:

```sh
nix develop --command git commit -m "message"
```

## Secrets and SSH

Secrets use [agenix](https://github.com/ryantm/agenix) (age-encrypted) via the home-manager module, split across two repos:

- **nix-config** (this repo): agenix module wiring in `flake.nix` (all helpers import `agenix.homeManagerModules.default`), age identity path in `home/default.nix`, SSH client config in `home/ssh/`.
- **nix-config-personal**: encrypted `.age` files in `secrets/`, recipients in `secrets/secrets.nix`, and the home-manager modules that declare `age.secrets.*`. Public repo — `.age` files are encrypted, so that's safe.

How it works: a single portable **age key** (`~/.config/agenix/age-key.txt`, no passphrase) is the decryption identity, copied to every machine. `make switch` activates the agenix module, which decrypts to a per-user temp directory and symlinks to the declared paths (e.g. `~/.ssh/id_ed25519_github`). On macOS, `UseKeychain yes` + `AddKeysToAgent yes` stores key passphrases in Keychain after first use.

**Adding a secret or a new SSH key:** the workflow and the `id_ed25519_<purpose>` naming convention are documented in nix-config-personal's AGENTS.md, which is the canonical copy.

Never commit plaintext secrets, API keys, or private SSH keys to either repo.
