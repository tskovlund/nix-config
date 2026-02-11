# CLAUDE.md — nix-config conventions

This file documents how this repo is structured and how to extend it.

## Architecture

- **flake.nix**: Entry point. Declares inputs and wires up:
  - `darwinConfigurations."darwin"` — macOS, base + personal
  - `darwinConfigurations."darwin-base"` — macOS, base only
  - `homeConfigurations."linux"` — Linux, base + personal
  - `homeConfigurations."linux-base"` — Linux, base only
  - `devShells` — dev shell with commit hook setup (entered automatically via direnv)
- **hosts/**: Platform-specific *system* config (nix-darwin settings, not user config)
  - `hosts/darwin/default.nix` — base system config (Nix settings, fonts, base Homebrew casks, macOS system defaults)
  - `hosts/darwin/personal.nix` — personal system config (personal casks, Mac App Store apps). Imported via `darwinModules` in the personal `makeDarwin` call.
  - `nix.enable = false` in darwin config because Determinate Nix manages the Nix daemon. This means `nix.*` options are unavailable in nix-darwin — configure Nix settings via Determinate instead.
- **home/**: User environment modules managed by home-manager. This is where most config lives.
- **files/**: Raw config files that modules source or symlink
- **.githooks/**: Repo-local git hooks (pre-commit formats/lints, pre-push runs `nix flake check --all-systems`)
- **.envrc**: direnv config — runs `use flake` to enter the dev shell, which sets `core.hooksPath`

## Profiles: base vs personal

The base/personal split applies at both layers:

- **home-manager** (user config):
  - **`home/default.nix`** — base dev environment. Everything that belongs on any dev machine (shell, editor, git, CLI tools). New modules go here by default.
  - **`home/personal.nix`** — personal additions layered on top. Only for things that are clearly personal (personal SSH hosts, fun tools, personal aliases, Claude Code).
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
5. Copilot auto-reviews the PR via the "Protect main" ruleset — review its comments, reply/resolve as appropriate
6. Once CI passes and comments are resolved, merge
7. Pull main locally, delete the feature branch, prune stale remote tracking refs: `git fetch --prune`

Note: the pre-push hook runs `nix flake check` on every push (including direct-to-main). CI also runs on PRs with required status checks for both Linux and macOS.

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
- **Retrospective info goes in comments, not body edits.** Once an issue is closed, don't edit the body to add outcomes, decisions, or file lists. Add a comment instead. The issue body is the spec as it was when work started; comments preserve the timeline.
- **Labels:** `bug`, `enhancement`, `documentation`, `phase`, `ci`, `research`, `dependencies`, `github actions`. Apply at least one label to every issue.
- **No milestones or GitHub Projects.** Linear handles planning. The `phase` label is sufficient for grouping implementation phases.
- **Cross-reference related issues** using `#N` links. Reference Linear issues with their full URL when relevant.
- **Repo owner can bypass force-push protection** when needed (e.g., amending commits on a PR branch).

## Style preferences

- **Conventional commits.** All commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `type(scope): description`. Common types: `feat`, `fix`, `docs`, `chore`, `refactor`. Scope is optional (e.g., `feat(shell): add fzf integration`).
- **No ambiguous abbreviations.** Use explicit names: `makeDarwin` not `mkDarwin`, `homeModules` not `hm`. The Nix community loves `mk`-prefixed names (from `mkDerivation`) but we prefer clarity. Exception: don't rename things from upstream APIs (`lib.mkIf` stays as `lib.mkIf`).
- **Discuss every design choice with Thomas.** Don't make assumptions about preferences. Present options with trade-offs.

## Module conventions

- Each module directory has a `default.nix` entry point
- Use `programs.<name>` and `home.file` over raw file writes when possible — home-manager options give you type checking and merging
- Keep modules focused: one concern per directory (shell, git, editor, etc.)
- **Platform-specific config:** Use dedicated platform modules (`home/darwin/`, `home/linux/`) rather than `isDarwin`/`isLinux` conditionals in shared modules. These are wired into `makeDarwin` in `flake.nix` via `darwinHomeModules`. Small one-off checks with `pkgs.stdenv.isDarwin` are acceptable, but growing platform-specific config should move to the platform module.

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
- `make check` — validate flake (both platforms)
- `make fmt` — format all Nix files with nixfmt
- `make lint` — lint all Nix files with statix + deadnix
- `make update` — update all inputs
- `nix repl --file flake.nix` — explore the flake interactively

**Important:** Git commands that trigger hooks (commit, push) require dev shell tools (`nixfmt`, `statix`, `deadnix`). Prefix with `nix develop --command` if not already in the dev shell:
```sh
nix develop --command git commit -m "message"
```

## Secrets

Secrets use agenix (age-encrypted). Never commit plaintext secrets, API keys, or private SSH keys. The `secrets/` directory will contain `.age` files only.
