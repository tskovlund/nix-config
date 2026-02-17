# nix-config Makefile
#
# Supported platforms:
#   darwin       — macOS via nix-darwin + home-manager (system + user config)
#   linux        — any Linux distro via standalone home-manager (user config only)
#   nixos-wsl    — NixOS on WSL via nixos-rebuild + home-manager module (full system)
#   miles        — Hetzner VPS via nixos-rebuild + home-manager module (remote deploy)
#
# `make switch` auto-detects the current platform.
# Explicit targets (e.g. `make switch-darwin`) always work regardless of platform.
#
# Why --flake .#name? nix-darwin auto-detects by hostname, but we use generic
# names so the config is portable. The Makefile handles the flag for you.
#
# Personal identity override:
# All switch targets require a personal identity flake. Configure it with:
#   mkdir -p ~/.config/nix-config
#   echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input
# Or pass it directly: make switch PERSONAL_INPUT=path:/path/to/nix-config-personal

SHELL := bash

UNAME := $(shell uname -s)
IS_NIXOS := $(shell [ -e /etc/NIXOS ] && echo 1 || echo 0)
IS_WSL := $(shell [ -n "$$WSL_DISTRO_NAME" ] && echo 1 || (grep -qi microsoft /proc/version 2>/dev/null && echo 1 || echo 0))

# Pass IMPURE=1 to enable --impure (needed for ~/.config/nix-config/local.nix)
IMPURE_FLAG := $(if $(IMPURE),--impure,)

# Pass REFRESH=1 to bypass Nix's input cache (forces re-fetch of all inputs)
REFRESH_FLAG := $(if $(REFRESH),--refresh,)

# Remote VPS host for deployment (override: make deploy-miles MILES_HOST=root@1.2.3.4)
MILES_HOST ?= root@<miles-ip>

# --no-write-lock-file prevents switch from modifying flake.lock when
# --override-input is used (the override is transient, not a lock change).
# Update the lock explicitly with `make update`.

# --- Personal identity override ---

PERSONAL_INPUT_FILE := $(HOME)/.config/nix-config/personal-input
OVERRIDE_FLAGS :=

ifndef PERSONAL_INPUT
  ifneq ($(wildcard $(PERSONAL_INPUT_FILE)),)
    PERSONAL_INPUT := $(strip $(shell cat $(PERSONAL_INPUT_FILE)))
  endif
endif

# SSH fallback: SSH keys are agenix secrets deployed by the build itself,
# creating a chicken-and-egg on fresh installs. When the personal input is a
# GitHub SSH URL and no SSH identity files exist yet, fall back to the github:
# shorthand (unauthenticated tarball download). Same as bootstrap.sh's
# github_shorthand().
ifneq ($(findstring git+ssh://git@github.com/,$(PERSONAL_INPUT)),)
  ifeq ($(wildcard $(HOME)/.ssh/id_ed25519_*),)
    _ORIG_URL := $(PERSONAL_INPUT)
    PERSONAL_INPUT := $(patsubst git+ssh://git@github.com/%,github:%,$(patsubst %.git,%,$(_ORIG_URL)))
    $(info ==> No SSH keys found — using $(PERSONAL_INPUT) instead of $(_ORIG_URL))
  endif
endif

# Sudo SSH fallback: sudo targets (NixOS, darwin) run as root, which may not
# have access to the user's SSH keys. Pre-compute a github: fallback URL so
# sudo-rebuild can retry on SSH auth failure. Only set when PERSONAL_INPUT is
# still a GitHub SSH URL (i.e. the bootstrap fallback above didn't trigger).
_FALLBACK_FLAGS :=
ifneq ($(findstring git+ssh://git@github.com/,$(PERSONAL_INPUT)),)
  _FALLBACK_PERSONAL := $(patsubst git+ssh://git@github.com/%,github:%,$(patsubst %.git,%,$(PERSONAL_INPUT)))
  _FALLBACK_FLAGS := --override-input personal $(_FALLBACK_PERSONAL)
endif

ifneq ($(strip $(PERSONAL_INPUT)),)
  OVERRIDE_FLAGS += --override-input personal $(PERSONAL_INPUT)
endif

# Runs a sudo rebuild with SSH fallback for GitHub URLs. Pipes output through
# tee so the user sees real-time progress. If the build fails due to SSH auth
# errors (root can't access user's SSH keys) and a github: fallback is
# available, retries with the github: shorthand.
# Usage: $(call sudo-rebuild,<rebuild-command>,<flake-target>)
define sudo-rebuild
@set -eo pipefail; _log=$$(mktemp); trap 'rm -f "$$_log"' EXIT; \
if sudo $(1) --flake .#$(2) --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG) 2>&1 | tee "$$_log"; then \
  true; \
elif grep -qE "(Permission denied \(publickey\)|Host key verification failed)" "$$_log" && [ -n "$(_FALLBACK_FLAGS)" ]; then \
  echo ""; \
  echo "==> SSH to GitHub failed under sudo — retrying with github: shorthand..."; \
  sudo $(1) --flake .#$(2) --no-write-lock-file $(_FALLBACK_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG); \
else \
  exit 1; \
fi
endef

# Warn if age key is missing (secrets won't decrypt without it).
# Non-blocking: base profile doesn't need it, but the warning helps catch
# the case where someone forgot to copy the key to a new machine.
define warn-agenix
@if [ ! -f "$(HOME)/.config/agenix/age-key.txt" ]; then \
  echo ""; \
  echo "==> WARNING: Age key not found at ~/.config/agenix/age-key.txt"; \
  echo "  Agenix secrets (SSH keys, etc.) will NOT be decrypted."; \
  echo "  If using the personal profile, copy the key from another machine:"; \
  echo "    scp <other-machine>:~/.config/agenix/age-key.txt ~/.config/agenix/age-key.txt"; \
  echo "  Or generate a new one (you'll need to re-encrypt secrets):"; \
  echo "    mkdir -p ~/.config/agenix && age-keygen -o ~/.config/agenix/age-key.txt"; \
  echo ""; \
fi
endef

.PHONY: switch switch-base bootstrap check update fmt lint clean .check-identity
.PHONY: switch-darwin switch-darwin-base
.PHONY: switch-linux switch-linux-base
.PHONY: switch-nixos-wsl switch-nixos-wsl-base
.PHONY: deploy-miles deploy-miles-base

# --- Identity check (only for switch targets) ---

.check-identity:
ifeq ($(strip $(OVERRIDE_FLAGS)),)
	@echo "Error: Personal identity not configured."
	@echo ""
	@echo "This config requires a personal identity flake to set your username,"
	@echo "name, and email. Create the config file:"
	@echo ""
	@echo "  mkdir -p ~/.config/nix-config"
	@echo '  echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input'
	@echo ""
	@echo "Or pass it directly:"
	@echo "  make switch PERSONAL_INPUT=git+ssh://git@github.com/YOUR_USER/nix-config-personal"
	@echo ""
	@echo "For local development with a checkout:"
	@echo "  make switch PERSONAL_INPUT=path:/path/to/nix-config-personal"
	@echo ""
	@echo "See README.md for details."
	@exit 1
endif

# --- Auto-detecting targets ---

ifeq ($(UNAME),Darwin)
switch: .check-identity
	$(call sudo-rebuild,darwin-rebuild switch,darwin)

switch-base: .check-identity
	$(call sudo-rebuild,darwin-rebuild switch,darwin-base)
else ifeq ($(IS_NIXOS),1)
ifeq ($(IS_WSL),1)
switch: .check-identity
	$(call sudo-rebuild,nixos-rebuild switch,nixos-wsl)
	$(warn-agenix)
	@systemctl --user start agenix 2>/dev/null || true

switch-base: .check-identity
	$(call sudo-rebuild,nixos-rebuild switch,nixos-wsl-base)
	$(warn-agenix)
	@systemctl --user start agenix 2>/dev/null || true
else
HOSTNAME := $(shell hostname)
ifeq ($(HOSTNAME),miles)
switch: .check-identity
	$(call sudo-rebuild,nixos-rebuild switch,miles)
	$(warn-agenix)

switch-base: .check-identity
	$(call sudo-rebuild,nixos-rebuild switch,miles-base)
	$(warn-agenix)
else
switch:
	@echo "Error: NixOS detected but no specific host configured in auto-detect."
	@echo "Use an explicit target: make switch-nixos-wsl, make deploy-miles, etc."
	@exit 1

switch-base:
	@echo "Error: NixOS detected but no specific host configured in auto-detect."
	@echo "Use an explicit target: make switch-nixos-wsl-base, make deploy-miles-base, etc."
	@exit 1
endif
endif
else
switch: .check-identity
	home-manager switch --flake .#linux --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG)
	$(warn-agenix)

switch-base: .check-identity
	home-manager switch --flake .#linux-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG)
	$(warn-agenix)
endif

# --- Explicit platform targets ---

switch-darwin: .check-identity
	$(call sudo-rebuild,darwin-rebuild switch,darwin)
	$(warn-agenix)

switch-darwin-base: .check-identity
	$(call sudo-rebuild,darwin-rebuild switch,darwin-base)
	$(warn-agenix)

switch-linux: .check-identity
	home-manager switch --flake .#linux --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG)
	$(warn-agenix)

switch-linux-base: .check-identity
	home-manager switch --flake .#linux-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG)
	$(warn-agenix)

switch-nixos-wsl: .check-identity
	$(call sudo-rebuild,nixos-rebuild switch,nixos-wsl)
	$(warn-agenix)
	@systemctl --user start agenix 2>/dev/null || true

switch-nixos-wsl-base: .check-identity
	$(call sudo-rebuild,nixos-rebuild switch,nixos-wsl-base)
	$(warn-agenix)
	@systemctl --user start agenix 2>/dev/null || true

# --- miles (Hetzner VPS) remote deployment ---
# Initial install: nix run github:nix-community/nixos-anywhere -- --flake .#miles root@<ip>
# Subsequent updates use these targets (builds on VPS, deploys on VPS):

deploy-miles: .check-identity
	nixos-rebuild switch --flake .#miles --target-host $(MILES_HOST) --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG)

deploy-miles-base: .check-identity
	nixos-rebuild switch --flake .#miles-base --target-host $(MILES_HOST) --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG) $(REFRESH_FLAG)

# Post-deploy initialization (gh auth, Claude settings, manual step reminders)
bootstrap:
	@bash scripts/post-bootstrap.sh

# --- Shared targets ---

check:
	nix flake check --all-systems

update:
	nix flake update

fmt:
	find . -name '*.nix' -not -path './result/*' | xargs nixfmt

lint:
	statix check . -i result/
	deadnix --no-lambda-pattern-names .

clean:
	rm -rf result
