{
  config,
  pkgs,
  lib,
  ...
}:

let
  wslCudaLib = "/usr/lib/wsl/lib";
in
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
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

  # ollama-cuda is unfree, so cache.nixos.org never carries it and every
  # nixpkgs bump rebuilds its CUDA kernels locally (about an hour on 12 cores).
  # The CUDA maintainers' cache serves the toolkit it depends on, which trims
  # the rebuild even when the ollama package itself is not cached.
  nix.settings = {
    substituters = [ "https://cuda-maintainers.cachix.org" ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };
}
