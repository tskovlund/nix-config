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
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, agenix, ... }:
    let
      username = "thomas";

      # Helper: create a nix-darwin system with the given home-manager modules.
      makeDarwin = homeModules: nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./hosts/darwin
          home-manager.darwinModules.home-manager
          {
            users.users.${username}.home = "/Users/${username}";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.${username} = {
              imports = homeModules;
              home.username = username;
              home.homeDirectory = "/Users/${username}";
            };
          }
        ];
      };

      # Helper: create a standalone home-manager config with the given modules.
      makeLinux = homeModules: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = homeModules ++ [
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
          }
        ];
      };

      # Module sets
      baseModules = [ ./home ];
      personalModules = baseModules ++ [ ./home/personal.nix ];
    in
    {
      # macOS — base + personal (default for personal machines)
      # Apply with: darwin-rebuild switch --flake .#darwin
      darwinConfigurations."darwin" = makeDarwin personalModules;

      # macOS — base only (dev environment without personal additions)
      # Apply with: darwin-rebuild switch --flake .#darwin-base
      darwinConfigurations."darwin-base" = makeDarwin baseModules;

      # Linux — base + personal
      # Apply with: home-manager switch --flake .#linux
      homeConfigurations."linux" = makeLinux personalModules;

      # Linux — base only
      # Apply with: home-manager switch --flake .#linux-base
      homeConfigurations."linux-base" = makeLinux baseModules;

      # Dev shell — enter with `nix develop` or automatically via direnv
      # Sets up commit hooks on entry
      devShells."aarch64-darwin".default = let
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      in pkgs.mkShell {
        shellHook = ''
          git config core.hooksPath .githooks
        '';
      };

      devShells."x86_64-linux".default = let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.mkShell {
        shellHook = ''
          git config core.hooksPath .githooks
        '';
      };
    };
}
