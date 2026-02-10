# nix-config Makefile
#
# `make switch` auto-detects macOS vs Linux and applies the right config.
#
# Why the explicit --flake .#name?
# nix-darwin auto-detects configs by hostname, but we use generic names
# ("darwin", "linux") so the config is portable across machines without
# renaming. This Makefile handles the flag for you.

UNAME := $(shell uname -s)

.PHONY: switch switch-base check update fmt lint clean

ifeq ($(UNAME),Darwin)
# macOS: rebuild system + home config via nix-darwin
switch:
	sudo darwin-rebuild switch --flake .#darwin

switch-base:
	sudo darwin-rebuild switch --flake .#darwin-base
else
# Linux: rebuild home config via standalone home-manager
switch:
	home-manager switch --flake .#linux

switch-base:
	home-manager switch --flake .#linux-base
endif

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
