# nix-config Makefile
#
# Supported platforms:
#   darwin       — macOS via nix-darwin + home-manager (system + user config)
#   linux        — any Linux distro via standalone home-manager (user config only)
#   nixos-wsl    — NixOS on WSL via nixos-rebuild + home-manager module (full system)
#   nixos        — generic NixOS via nixos-rebuild + home-manager module (future: VPS, bare-metal)
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

UNAME := $(shell uname -s)
IS_NIXOS := $(shell [ -e /etc/NIXOS ] && echo 1 || echo 0)
IS_WSL := $(shell [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] && echo 1 || echo 0)

# Pass IMPURE=1 to enable --impure (needed for ~/.config/nix-config/local.nix)
IMPURE_FLAG := $(if $(IMPURE),--impure,)

# --- Personal identity override ---

PERSONAL_INPUT_FILE := $(HOME)/.config/nix-config/personal-input
OVERRIDE_FLAGS :=

ifdef PERSONAL_INPUT
  OVERRIDE_FLAGS += --override-input personal $(PERSONAL_INPUT)
else ifneq ($(wildcard $(PERSONAL_INPUT_FILE)),)
  PERSONAL_INPUT := $(strip $(shell cat $(PERSONAL_INPUT_FILE)))
  ifneq ($(PERSONAL_INPUT),)
    OVERRIDE_FLAGS += --override-input personal $(PERSONAL_INPUT)
  endif
endif

.PHONY: switch switch-base bootstrap check update fmt lint clean .check-identity
.PHONY: switch-darwin switch-darwin-base
.PHONY: switch-linux switch-linux-base
.PHONY: switch-nixos-wsl switch-nixos-wsl-base

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
	sudo darwin-rebuild switch --flake .#darwin --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-base: .check-identity
	sudo darwin-rebuild switch --flake .#darwin-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)
else ifeq ($(IS_NIXOS),1)
ifeq ($(IS_WSL),1)
switch: .check-identity
	sudo nixos-rebuild switch --flake .#nixos-wsl --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-base: .check-identity
	sudo nixos-rebuild switch --flake .#nixos-wsl-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)
else
switch:
	@echo "Error: NixOS detected but no specific host configured in auto-detect."
	@echo "Use an explicit target: make switch-nixos-wsl, etc."
	@exit 1

switch-base:
	@echo "Error: NixOS detected but no specific host configured in auto-detect."
	@echo "Use an explicit target: make switch-nixos-wsl-base, etc."
	@exit 1
endif
else
switch: .check-identity
	home-manager switch --flake .#linux --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-base: .check-identity
	home-manager switch --flake .#linux-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)
endif

# --- Explicit platform targets ---

switch-darwin: .check-identity
	sudo darwin-rebuild switch --flake .#darwin --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-darwin-base: .check-identity
	sudo darwin-rebuild switch --flake .#darwin-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-linux: .check-identity
	home-manager switch --flake .#linux --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-linux-base: .check-identity
	home-manager switch --flake .#linux-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-nixos-wsl: .check-identity
	sudo nixos-rebuild switch --flake .#nixos-wsl --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-nixos-wsl-base: .check-identity
	sudo nixos-rebuild switch --flake .#nixos-wsl-base --no-write-lock-file $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

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
