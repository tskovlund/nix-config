{
  config,
  pkgs,
  lib,
  nixpkgs-cuda,
  ...
}:

let
  wslCudaLib = "/usr/lib/wsl/lib";

  # ollama-cuda comes from the separately pinned nixpkgs-cuda input (see
  # flake.nix). It is unfree, so no public binary cache carries it, and a
  # fresh build compiles every CUDA kernel locally for an hour or more.
  # The pin is deliberate (nix-config#98): Renovate is told to ignore the
  # input in renovate.json, so ollama only moves when someone bumps the rev
  # by hand, with time set aside for the build.
  cudaPkgs = import nixpkgs-cuda {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  services.ollama = {
    enable = true;
    package = cudaPkgs.ollama-cuda;
    environmentVariables = {
      LD_LIBRARY_PATH = "${wslCudaLib}:\${LD_LIBRARY_PATH:-}";
    };
    loadModels = [
      "qwen2.5-coder:3b"
    ];
  };

  systemd.services.ollama.serviceConfig = {
    SupplementaryGroups = [ "render" ];
  };

  # Bumping the pin rebuilds ollama-cuda from source, and an uncapped build
  # (twelve nvcc jobs at 1 to 1.5 GB each) took the 7 GB WSL VM down once
  # (nix-config#92). Cap build parallelism on this host so that build is slow
  # but survives; everything else the host needs comes from cache.nixos.org,
  # so the cap costs nothing on a routine switch. The CUDA toolkit itself is
  # not in any public cache either (cuda-maintainers.cachix.org is gone), so
  # there is no substituter worth adding here.
  nix.settings = {
    max-jobs = 1;
    cores = 3;
  };
}
