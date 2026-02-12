{
  description = "Portable Nix environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Personal identity (private). Default: stub with placeholder values.
    # Override with real identity on personal machines — see README.
    personal.url = "path:./stubs/personal";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      agenix,
      nixvim,
      mcp-servers-nix,
      nixos-wsl,
      personal,
      ...
    }:
    let
      inherit (personal) identity;
      inherit (identity) username;

      # Optional machine-local home-manager config (outside the repo).
      # Requires --impure to take effect; silently skipped in pure evaluation.
      localModules =
        homeDir:
        let
          path = /. + "${homeDir}/.config/nix-config/local.nix";
        in
        if builtins.pathExists path then [ path ] else [ ];

      # Helper: create a nix-darwin system with the given modules.
      # homeModules: home-manager modules (cross-platform user config)
      # darwinModules: extra nix-darwin system modules (e.g. hosts/darwin/personal.nix)
      makeDarwin =
        {
          homeModules,
          darwinModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./hosts/darwin
            { nixpkgs.overlays = [ mcp-servers-nix.overlays.default ]; }
            home-manager.darwinModules.home-manager
            {
              system.primaryUser = username;
              users.users.${username}.home = "/Users/${username}";
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.extraSpecialArgs = { inherit identity; };
              home-manager.users.${username} = {
                imports =
                  homeModules
                  ++ darwinHomeModules
                  ++ [ nixvim.homeModules.nixvim ]
                  ++ localModules "/Users/${username}";
                home.username = username;
                home.homeDirectory = "/Users/${username}";
              };
            }
          ]
          ++ darwinModules;
        };

      # Helper: create a standalone home-manager config with the given modules.
      # Uses import (not legacyPackages) so we can configure allowUnfreePredicate.
      makeLinux =
        homeModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [ mcp-servers-nix.overlays.default ];
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "claude-code-bin"
              ];
          };
          extraSpecialArgs = { inherit identity; };
          modules =
            homeModules
            ++ localModules "/home/${username}"
            ++ [
              nixvim.homeModules.nixvim
              {
                home.username = username;
                home.homeDirectory = "/home/${username}";
              }
            ];
        };

      # Helper: create a NixOS system with the given modules.
      # homeModules: home-manager modules (cross-platform user config)
      # nixosModules: extra NixOS system modules (e.g. hosts/nixos-wsl/default.nix)
      makeNixOS =
        {
          system,
          hostname,
          homeModules,
          nixosModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/nixos
            { nixpkgs.overlays = [ mcp-servers-nix.overlays.default ]; }
            home-manager.nixosModules.home-manager
            (
              { pkgs, ... }:
              {
                networking.hostName = hostname;
                nixpkgs.hostPlatform = system;
                # Configure the user account
                users.users.${username} = {
                  isNormalUser = true;
                  shell = pkgs.zsh;
                  extraGroups = [ "wheel" ];
                };
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "hm-backup";
                home-manager.extraSpecialArgs = { inherit identity; };
                home-manager.users.${username} = {
                  imports =
                    homeModules
                    ++ [ nixvim.homeModules.nixvim ]
                    ++ localModules "/home/${username}";
                  home.username = username;
                  home.homeDirectory = "/home/${username}";
                };
              }
            )
          ]
          ++ nixosModules;
        };

      # Module sets
      baseModules = [ ./home ];
      personalModules = baseModules ++ [ ./home/personal.nix ];
      darwinHomeModules = [ ./home/darwin ];

      # Helper: create a dev shell with formatting/linting tools and hook setup.
      makeDevShell =
        pkgs:
        pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            statix
            deadnix
          ];
          shellHook = ''
            git config core.hooksPath .githooks
          '';
        };
    in
    {
      # macOS — base + personal (default for personal machines)
      # Apply with: darwin-rebuild switch --flake .#darwin
      darwinConfigurations."darwin" = makeDarwin {
        homeModules = personalModules;
        darwinModules = [ ./hosts/darwin/personal.nix ];
      };

      # macOS — base only (dev environment without personal additions)
      # Apply with: darwin-rebuild switch --flake .#darwin-base
      darwinConfigurations."darwin-base" = makeDarwin {
        homeModules = baseModules;
      };

      # Linux — base + personal
      # Apply with: home-manager switch --flake .#linux
      homeConfigurations."linux" = makeLinux personalModules;

      # Linux — base only
      # Apply with: home-manager switch --flake .#linux-base
      homeConfigurations."linux-base" = makeLinux baseModules;

      # NixOS-WSL — base + personal
      # Apply with: nixos-rebuild switch --flake .#nixos-wsl
      nixosConfigurations."nixos-wsl" = makeNixOS {
        system = "x86_64-linux";
        hostname = "nixos-wsl";
        homeModules = personalModules;
        nixosModules = [
          ./hosts/nixos-wsl
          nixos-wsl.nixosModules.wsl
          { wsl.defaultUser = username; }
        ];
      };

      # NixOS-WSL — base only
      # Apply with: nixos-rebuild switch --flake .#nixos-wsl-base
      nixosConfigurations."nixos-wsl-base" = makeNixOS {
        system = "x86_64-linux";
        hostname = "nixos-wsl-base";
        homeModules = baseModules;
        nixosModules = [
          ./hosts/nixos-wsl
          nixos-wsl.nixosModules.wsl
          { wsl.defaultUser = username; }
        ];
      };

      # Dev shell — enter with `nix develop` or automatically via direnv
      # Provides formatting/linting tools and sets up commit hooks
      devShells."aarch64-darwin".default = makeDevShell nixpkgs.legacyPackages.aarch64-darwin;
      devShells."x86_64-linux".default = makeDevShell nixpkgs.legacyPackages.x86_64-linux;
    };
}
