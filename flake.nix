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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Personal identity (external). Default: stub with placeholder values.
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
      nixos-wsl,
      disko,
      personal,
      ...
    }:
    let
      inherit (personal) identity;
      # personal.homeModules is an attrset with a `default` aggregate (the
      # shape flake-schemas requires); tolerate the legacy list shape and
      # the empty stub so either side can update first.
      personalHomeModules =
        let
          raw = personal.homeModules or [ ];
        in
        if builtins.isAttrs raw then [ raw.default ] else raw;
      inherit (identity) username;

      # Unfree packages allowed on every target. Defined once here and wired
      # into all three builders so the list lives in one place. The CUDA /
      # NVIDIA prefixes are for ollama-cuda (hosts/nixos-wsl/ollama.nix).
      allowUnfreePredicate =
        pkg:
        let
          name = nixpkgs.lib.getName pkg;
          prefixes = [
            "cuda"
            "cudnn"
            "libcu"
            "libnpp"
            "libnv"
            "nccl"
            "nvidia"
          ];
        in
        builtins.elem name [ "claude-code" ] || builtins.any (p: nixpkgs.lib.hasPrefix p name) prefixes;

      # nixpkgs settings shared by the nix-darwin and NixOS builders.
      nixpkgsModule = {
        nixpkgs.overlays = [ agenix.overlays.default ];
        nixpkgs.config = { inherit allowUnfreePredicate; };
      };

      # Optional machine-local home-manager config (outside the repo).
      # Requires --impure to take effect; silently skipped in pure evaluation.
      localModules =
        homeDir:
        let
          path = /. + "${homeDir}/.config/nix-config/local.nix";
        in
        if builtins.pathExists path then [ path ] else [ ];

      # Optional machine-local NixOS system config (outside the repo).
      # Requires --impure to take effect; silently skipped in pure evaluation.
      # Use for system-level overrides like security.pki, networking, etc.
      localSystemModules =
        homeDir:
        let
          path = /. + "${homeDir}/.config/nix-config/local-system.nix";
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
          specialArgs = { inherit username; };
          modules = [
            ./hosts/darwin
            nixpkgsModule
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
                  ++ [
                    nixvim.homeModules.nixvim
                    agenix.homeManagerModules.default
                  ]
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
            overlays = [ agenix.overlays.default ];
            config = { inherit allowUnfreePredicate; };
          };
          extraSpecialArgs = { inherit identity; };
          modules =
            homeModules
            ++ localModules "/home/${username}"
            ++ [
              nixvim.homeModules.nixvim
              agenix.homeManagerModules.default
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
          specialArgs = { inherit username; };
          modules = [
            ./hosts/nixos
            nixpkgsModule
            agenix.nixosModules.default
            {
              age.identityPaths = [ "/home/${username}/.config/agenix/age-key.txt" ];
            }
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
                  linger = true; # keep user systemd instance running so home-manager can start user services
                };
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "hm-backup";
                home-manager.extraSpecialArgs = { inherit identity; };
                home-manager.users.${username} = {
                  imports =
                    homeModules
                    ++ nixosHomeModules
                    ++ [
                      nixvim.homeModules.nixvim
                      agenix.homeManagerModules.default
                    ]
                    ++ localModules "/home/${username}";
                  home.username = username;
                  home.homeDirectory = "/home/${username}";
                };
              }
            )
          ]
          ++ nixosModules
          ++ localSystemModules "/home/${username}";
        };

      # Module sets
      baseModules = [ ./home ];
      personalModules = baseModules ++ [ ./home/personal.nix ];
      darwinHomeModules = [ ./home/darwin ];
      nixosHomeModules = [ ./home/nixos ];

      # Helper: create a dev shell with formatting/linting tools and hook setup.
      makeDevShell =
        pkgs:
        pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            statix
            deadnix
            nixos-rebuild
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
        homeModules = personalModules ++ personalHomeModules;
        darwinModules = [ ./hosts/darwin/personal.nix ];
      };

      # macOS — base only (dev environment without personal additions)
      # Apply with: darwin-rebuild switch --flake .#darwin-base
      darwinConfigurations."darwin-base" = makeDarwin {
        homeModules = baseModules;
      };

      # Linux — base + personal
      # Apply with: home-manager switch --flake .#linux
      homeConfigurations."linux" = makeLinux (personalModules ++ personalHomeModules);

      # Linux — base only
      # Apply with: home-manager switch --flake .#linux-base
      homeConfigurations."linux-base" = makeLinux baseModules;

      # NixOS-WSL — base + personal
      # Apply with: nixos-rebuild switch --flake .#nixos-wsl
      nixosConfigurations."nixos-wsl" = makeNixOS {
        system = "x86_64-linux";
        hostname = "nixos-wsl";
        homeModules = personalModules ++ personalHomeModules;
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

      # miles (Hetzner VPS) — base + personal
      # Initial deploy: nixos-anywhere. Updates: make deploy-miles
      nixosConfigurations."miles" = makeNixOS {
        system = "x86_64-linux";
        hostname = "miles";
        homeModules = personalModules ++ personalHomeModules;
        nixosModules = [
          disko.nixosModules.disko
          ./hosts/miles
        ];
      };

      # Dev shell — enter with `nix develop` or automatically via direnv
      # Provides formatting/linting tools and sets up commit hooks
      devShells."aarch64-darwin".default = makeDevShell nixpkgs.legacyPackages.aarch64-darwin;
      devShells."x86_64-linux".default = makeDevShell nixpkgs.legacyPackages.x86_64-linux;
    };
}
