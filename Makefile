# nix-config Makefile
#
# `make switch` auto-detects macOS vs Linux vs NixOS-WSL and applies the right config.
#
# Why the explicit --flake .#name?
# nix-darwin auto-detects configs by hostname, but we use generic names
# ("darwin", "linux", "wsl") so the config is portable across machines without
# renaming. This Makefile handles the flag for you.
#
# Personal identity override:
# All switch targets require a personal identity flake. Configure it with:
#   mkdir -p ~/.config/nix-config
#   echo "git+ssh://git@github.com/YOUR_USER/nix-config-personal" > ~/.config/nix-config/personal-input
# Or pass it directly: make switch PERSONAL_INPUT=path:/path/to/nix-config-personal

UNAME := $(shell uname -s)
IS_NIXOS := $(shell command -v nixos-rebuild >/dev/null 2>&1 && echo 1 || echo 0)
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

.PHONY: switch switch-base switch-wsl switch-wsl-base bootstrap check update fmt lint clean .check-identity

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

ifeq ($(UNAME),Darwin)
# macOS: rebuild system + home config via nix-darwin
switch: .check-identity
	sudo darwin-rebuild switch --flake .#darwin $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-base: .check-identity
	sudo darwin-rebuild switch --flake .#darwin-base $(OVERRIDE_FLAGS) $(IMPURE_FLAG)
else ifeq ($(IS_NIXOS),1)
# NixOS: rebuild system + home config via nixos-rebuild
ifeq ($(IS_WSL),1)
# NixOS-WSL detected
switch: .check-identity
	sudo nixos-rebuild switch --flake .#wsl $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-base: .check-identity
	sudo nixos-rebuild switch --flake .#wsl-base $(OVERRIDE_FLAGS) $(IMPURE_FLAG)
else
# Generic NixOS (future hosts like VPS)
switch:
	@echo "Error: NixOS detected but no specific host configured."
	@echo "For NixOS-WSL, use: make switch-wsl"
	@echo "For other NixOS hosts, add them to this Makefile."
	@exit 1

switch-base:
	@echo "Error: NixOS detected but no specific host configured."
	@echo "For NixOS-WSL, use: make switch-wsl-base"
	@exit 1
endif
else
# Linux: rebuild home config via standalone home-manager
switch: .check-identity
	home-manager switch --flake .#linux $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-base: .check-identity
	home-manager switch --flake .#linux-base $(OVERRIDE_FLAGS) $(IMPURE_FLAG)
endif

# Explicit NixOS-WSL targets (work on any platform if you want to build remotely)
switch-wsl: .check-identity
	sudo nixos-rebuild switch --flake .#wsl $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

switch-wsl-base: .check-identity
	sudo nixos-rebuild switch --flake .#wsl-base $(OVERRIDE_FLAGS) $(IMPURE_FLAG)

# Post-deploy initialization (gh auth, Claude settings, manual step reminders)
bootstrap:
	@bash scripts/post-bootstrap.sh

# Validate the flake without applying
check:
	nix flake check --all-systems

# Update all flake inputs to latest
update:
	nix flake update

# Format all Nix files
fmt:
	find . -name '*.nix' -not -path './result/*' | xargs nixfmt

# Lint all Nix files
lint:
	statix check . -i result/
	deadnix --no-lambda-pattern-names .

# Remove build artifacts
clean:
	rm -rf result
