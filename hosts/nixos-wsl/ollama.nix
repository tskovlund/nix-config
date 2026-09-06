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
  # fresh build compiles every CUDA kernel locally for hours. Pinning it keeps
  # routine nixpkgs bumps cheap; bump the input rev when there is time for it.
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

  # The CUDA maintainers' cache serves the CUDA toolkit ollama-cuda depends
  # on, which trims the rebuild when the pin above is eventually bumped.
  nix.settings = {
    substituters = [ "https://cuda-maintainers.cachix.org" ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };
}
