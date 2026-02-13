# CLAUDE.md — nix-config conventions

This file documents how this repo is structured and how to extend it.

## Architecture

- **flake.nix**: Entry point. Declares inputs and wires up:
  - `darwinConfigurations."darwin"` — macOS, base + personal
  - `darwinConfigurations."darwin-base"` — macOS, base only
  - `homeConfigurations."linux"` — Linux, base + personal
  - `homeConfigurations."linux-base"` — Linux, base only
  - `nixosConfigurations."nixos-wsl"` — NixOS-WSL, base + personal
  - `nixosConfigurations."nixos-wsl-base"` — NixOS-WSL, base only
  - `devShells` — dev shell with commit hook setup (entered automatically via direnv)
- **hosts/**: Platform-specific *system* config (nix-darwin settings, NixOS settings, not user config)
  - `hosts/darwin/default.nix` — base system config (Nix settings, fonts, base Homebrew casks, macOS system defaults)
  - `hosts/darwin/personal.nix` — personal system config (personal casks, Mac App Store apps). Imported via `darwinModules` in the personal `makeDarwin` call.
  - `nix.enable = false` in darwin config because Determinate Nix manages the Nix daemon. This means `nix.*` options are unavailable in nix-darwin — configure Nix settings via Determinate instead.
  - `hosts/nixos/default.nix` — general NixOS layer (user setup, flakes, zsh, home-manager integration). Reusable by all NixOS hosts (WSL, VPS, bare-metal, etc.)
  - `hosts/wsl/default.nix` — general WSL layer (interop, automount, start menu launchers). Reusable for any WSL distribution, not just NixOS-WSL.
  - `hosts/nixos-wsl/default.nix` — NixOS-WSL entry point. Imports the wsl layer; nixos layer is auto-imported by makeNixOS.
- **home/**: User environment modules managed by home-manager. This is where most config lives.
- **stubs/personal/**: Placeholder identity flake for CI. On real machines, `make switch` overrides this with the real personal flake via `~/.config/nix-config/personal-input`. See README for details.
- **files/**: Raw config files that modules source or symlink
- **bootstrap.sh**: Curl-pipeable bootstrap script for new machines. Installs Nix, Homebrew (macOS), clones repo, sets up identity, runs first deploy.
- **scripts/**: Support scripts (not Nix modules). Currently contains `post-bootstrap.sh` for post-deploy initialization.
- **.githooks/**: Repo-local git hooks (pre-commit formats/lints, pre-push runs `nix flake check --all-systems`)
- **.envrc**: direnv config — runs `use flake` to enter the dev shell, which sets `core.hooksPath`

## Personal identity

This repo contains no personal information. Identity (username, name, email) comes from an external **personal flake** input.

- **`inputs.personal`** defaults to `path:./stubs/personal` — a stub with placeholder values and `isStub = true`.
- On real machines, `make switch` reads `~/.config/nix-config/personal-input` and passes `--override-input personal <url>` to the rebuild command.
- The personal flake exports two things:
  - `identity = { isStub, username, fullName, email }` — consumed by `flake.nix` and `home/git/default.nix`
  - `homeModules` — list of home-manager modules for personal config (secrets, SSH, dotfiles). Imported by personal targets via `personalHomeModules` in `flake.nix`.
- In `flake.nix`, `username` is derived from `identity.username` and flows through to all system/user config via closures.
- Home-manager modules receive `identity` via `extraSpecialArgs`. Use `{ identity, ... }:` in the module args to access it. Currently only `home/git/default.nix` uses `identity.fullName` and `identity.email`.
- `nix flake check` in CI uses the stub (no override needed) and passes because stub values are valid strings. The stub exports `homeModules = []`.
- `make switch` without identity configured prints a clear error message.

## Profiles: base vs personal

The base/personal split applies at both layers:

- **home-manager** (user config):
  - **`home/default.nix`** — base dev environment. Everything that belongs on any dev machine (shell, editor, git, CLI tools). New modules go here by default.
  - **`home/personal.nix`** — personal additions layered on top. Only for things that are clearly personal (personal SSH hosts, fun tools, personal aliases).
- **nix-darwin** (system config):
  - **`hosts/darwin/default.nix`** — base system config including base Homebrew casks (Firefox, Chrome, iTerm2, etc.)
  - **`hosts/darwin/personal.nix`** — personal casks, Mac App Store apps, personal brew formulae.

When adding new config, put it in base unless it's obviously personal. When in doubt, ask.

## Adding a new home-manager module

1. Create `home/<category>/default.nix`
2. Import it from `home/default.nix` (for base) or `home/personal.nix` (for personal):
   ```nix
   imports = [
     ./shell
     ./git
     ./tools
     ./editor
     # add new module here
   ];
   ```
3. Test with `make check`, then `make switch`

## Git workflow

- **Direct to main**: config tweaks, bug fixes, small additions within an existing module
- **Branch + PR**: new modules/phases, structural changes to flake.nix, anything touching multiple modules

### PR workflow (branch + PR)

1. Create a feature branch: `git checkout -b feat/<name>`
2. Make changes, test with `make check` and `make switch`
3. Commit with conventional commit messages
4. Push and create a PR linking the relevant phase issue
5. **Review loop — iterate until clean:**
   - Wait for CI and Copilot review (Copilot auto-reviews via the "Protect main" ruleset)
   - Read all Copilot comments: `gh api repos/tskovlund/nix-config/pulls/<N>/comments`
   - Address each comment: fix the code, or reply explaining why no change is needed
   - Push fixes, then check for new comments — repeat until no unresolved comments remain
   - This loop is part of the definition of done. A PR is not ready for human review until CI passes and all automated review comments are resolved.
6. Once CI passes and comments are resolved, notify Thomas for final review
7. Thomas merges. After merge:
   - Pull main locally, delete the feature branch, prune stale remote tracking refs: `git fetch --prune`
   - Close related GitHub issues (if not auto-closed by `Closes #N`)
   - Update related Linear issues (add comment with PR link, move to Done)

Note: the pre-push hook runs `nix flake check` on every push (including direct-to-main). CI also runs on PRs with required status checks for both Linux and macOS.

### Agent autonomy

The goal is to maximize continuous agent work without human intervention. Agents should:
- Follow the PR review loop above autonomously — don't stop after the first push
- Use agent teams for parallel work when tasks are independent
- Pick up the next logical task after completing one (check Linear and GitHub issues)
- Only pause for human input when a design decision genuinely requires it
- Document all decisions and trade-offs in PR descriptions and issue comments so Thomas can review asynchronously

### PR structure

A PR template is defined in `.github/PULL_REQUEST_TEMPLATE.md`. When using `gh pr create --body`, follow the same structure:

- **Summary** — what this PR does and why, as a short list of bullet points.
- **Test plan** — checkboxes for how the change was verified. Always include `make check` and `make switch`. Add issue-specific verification steps as needed.
- **Related issues** — link related GitHub issues (`Closes #N` or `Related: #N`) and Linear issues (full URL).

### Keeping docs current

- **README.md** and **CLAUDE.md** must be updated whenever changes affect them (new modules, new tools, workflow changes, architectural decisions)
- **GitHub issues** conventions are documented below

### Issue tracking

GitHub Issues is the implementation tracker for this repo. Linear handles higher-level planning.

**Issue types and templates:**

Three issue templates are defined in `.github/ISSUE_TEMPLATE/`. Always use the appropriate template when creating issues — via the GitHub web UI (which presents template selection) or by following the template structure when using `gh issue create`.

- **Enhancement** — new features or improvements. Sections: Summary, Why, Requirements (checkboxes), Caveats, Acceptance criteria, References.
- **Bug** — something broken. Sections: Summary, Problem, Fix (checkboxes), Context, Acceptance criteria.
- **Research** — exploratory / future consideration. Sections: What, Why consider it, Why not now, References, Trigger to revisit. Research issues do **not** have acceptance criteria — they end with "Trigger to revisit" instead.

**Conventions:**

- **Acceptance criteria on every actionable issue.** Every enhancement and bug must have an explicit "Acceptance criteria" section with verifiable conditions. This is how we know when an issue is done.
- **No "Status:" headers in issue bodies.** GitHub's open/closed state tracks status. Don't add "Status: Not started" or "Status: Done" lines to issue descriptions.
- **Don't edit issue bodies — use comments.** The issue body is the original spec. New context, corrections, investigation findings, and retrospective info all go in comments, preserving the timeline. The only exceptions are fixing typos, adding missing template sections before work starts, or ticking checkboxes (in issues, PRs, etc.).
- **Always read issue comments before working on an issue.** Comments are a crucial part of issue tracking — they contain scope changes, investigation findings, design decisions, and context that the body alone won't have. The body may be outdated or incomplete. Skip this only when the issue is obviously simple or freshly created.
- **Labels:** `bug`, `enhancement`, `documentation`, `phase`, `ci`, `research`, `dependencies`, `github actions`. Apply at least one label to every issue.
- **No milestones or GitHub Projects.** Linear handles planning. The `phase` label is sufficient for grouping implementation phases.
- **Cross-reference related issues** using `#N` links. Reference Linear issues with their full URL when relevant.
- **Repo owner can bypass force-push protection** when needed (e.g., amending commits on a PR branch).

## Style preferences

- **Conventional commits.** All commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `type(scope): description`. Common types: `feat`, `fix`, `docs`, `chore`, `refactor`. Include scope when a commit touches a single module; omit for cross-cutting changes. Use these scopes consistently:
  - **Module scopes** (map to `home/<dir>/`): `shell`, `git`, `editor`, `tools`, `claude`, `darwin`, `linux`
  - **Infra scopes**: `ci`, `bootstrap`, `flake`, `deps`
  - Example: `feat(shell): add fzf integration`, `fix(claude): skip tmux for non-interactive subcommands`, `chore(deps): update flake inputs`
- **No ambiguous abbreviations.** Use explicit names: `makeDarwin` not `mkDarwin`, `homeModules` not `hm`. The Nix community loves `mk`-prefixed names (from `mkDerivation`) but we prefer clarity. Exception: don't rename things from upstream APIs (`lib.mkIf` stays as `lib.mkIf`).
- **Discuss every design choice with Thomas.** Don't make assumptions about preferences. Present options with trade-offs.
- **Proper fixes over workarounds.** Always solve problems at the root cause. Workarounds are acceptable only for sufficiently small problems, with clear justification, and require explicit confirmation from Thomas. If a workaround is used, document why and create a follow-up issue for the proper fix. Workarounds erode maintainability over time — resist them by default.
- **Verify UI changes before pushing.** For visual/UI changes (prompts, themes, TUI output, etc.) where `make check` can't confirm correctness, `make switch` first and ask Thomas to verify the result visually before committing and pushing.
- **Use the best model for the job.** Cost is not a concern. When spawning agents for complex tasks, use Opus (with extended thinking if beneficial). Use Sonnet for straightforward, well-scoped subtasks.

## Module conventions

- Each module directory has a `default.nix` entry point
- Use `programs.<name>` and `home.file` over raw file writes when possible — home-manager options give you type checking and merging
- Keep modules focused: one concern per directory (shell, git, editor, etc.)
- **Platform-specific config:** Use dedicated platform modules (`home/darwin/`, `home/nixos/`) rather than `isDarwin`/`isLinux` conditionals in shared modules. These are wired into helpers in `flake.nix` via `darwinHomeModules` / `nixosHomeModules`. Small one-off checks with `pkgs.stdenv.isDarwin` are acceptable, but growing platform-specific config should move to the platform module.

## Machine-local config

Optional local config lives at `~/.config/nix-config/local.nix` (outside the repo). It's imported as a home-manager module by all targets (base and personal) when present and `--impure` is used. Without `--impure`, it's silently skipped.

- Apply with: `make switch IMPURE=1`
- The file is a standard home-manager module (receives `{ pkgs, ... }`)
- `nix flake check` and CI are unaffected (pure evaluation = local.nix ignored)
- See `examples/local.nix` for a starter template

## State versions — never change these

- `system.stateVersion = 5` in `hosts/darwin/default.nix`
- `system.stateVersion = "25.05"` in `hosts/nixos/default.nix`
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

- `bootstrap.sh` — new-machine bootstrap (installs Nix, clones, deploys)
- `make bootstrap` — post-deploy initialization (gh auth, Claude settings, manual step reminders)
- `make switch` — apply base + personal config (auto-detects macOS / Linux / NixOS-WSL)
- `make switch-base` — apply base only config (auto-detects platform)
- `make switch-darwin` / `switch-darwin-base` — explicit macOS targets
- `make switch-linux` / `switch-linux-base` — explicit Linux (standalone home-manager) targets
- `make switch-nixos-wsl` / `switch-nixos-wsl-base` — explicit NixOS-WSL targets
- `make check` — validate flake (all platforms)
- `make fmt` — format all Nix files with nixfmt
- `make lint` — lint all Nix files with statix + deadnix
- `make update` — update all inputs
- `nix repl --file flake.nix` — explore the flake interactively
- `c` / `claude` — run Claude Code normally
- `ct` / `claude-team` — launches Claude Code inside tmux -CC (iTerm2 control mode) so agent team splits render as native iTerm2 panes. Use for agent team sessions.

**Important:** Git commands that trigger hooks (commit, push) require dev shell tools (`nixfmt`, `statix`, `deadnix`). Prefix with `nix develop --command` if not already in the dev shell:
```sh
nix develop --command git commit -m "message"
```

## Persistent memory (MCP)

See global CLAUDE.md for full MCP memory guidelines (proactive querying, what to store vs keep in CLAUDE.md).

The memory server binary is Nix-managed (`home/claude/default.nix`). MCP registration is a one-time manual step — see `docs/manual-setup.md`.

## Secrets and SSH

Secrets use [agenix](https://github.com/ryantm/agenix) (age-encrypted) via the home-manager module. The architecture splits across two repos:

- **nix-config** (public): agenix module wiring in `flake.nix` (all helpers import `agenix.homeManagerModules.default`), age identity path in `home/default.nix`, SSH client config in `home/ssh/`.
- **nix-config-personal** (private): encrypted `.age` files in `secrets/`, recipient definitions in `secrets/secrets.nix`, home-manager modules in `home/` that declare `age.secrets.*` and wire SSH/git config.

### How it works

1. A single **age key** (`~/.config/agenix/age-key.txt`) is the decryption identity. It's portable — the same key is copied to every machine. No passphrase.
2. Secrets are encrypted against this key's public key and stored as `.age` files in nix-config-personal.
3. `make switch` activates the agenix home-manager module, which decrypts secrets to a per-user temp directory and symlinks them to their declared paths (e.g. `~/.ssh/id_ed25519_github`).
4. On macOS, `UseKeychain yes` + `AddKeysToAgent yes` means SSH key passphrases are stored in Keychain after first use.

### SSH key naming convention

Keys follow `id_ed25519_<purpose>`:
- `id_ed25519_github` — GitHub authentication + commit signing
- Future: `id_ed25519_server`, `id_ed25519_work`, etc.

### Adding a new secret

1. Add the `.age` file entry to `secrets/secrets.nix` in nix-config-personal
2. Encrypt: `agenix -e secrets/<name>.age` (or use `age -r <pubkey> -o <file>`)
3. Declare `age.secrets.<name>` in a home-manager module under nix-config-personal's `home/`
4. Reference the decrypted path via `config.age.secrets.<name>.path`

Never commit plaintext secrets, API keys, or private SSH keys to either repo.
