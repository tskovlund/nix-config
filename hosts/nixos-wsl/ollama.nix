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
}
