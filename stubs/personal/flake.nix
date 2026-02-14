{
  description = "Stub identity for nix-config (replace with real personal flake)";

  outputs =
    { ... }:
    {
      identity = {
        isStub = true;
        username = "user";
        fullName = "Nix User";
        email = "user@example.com";
      };

      # Real personal flake exports home-manager modules (secrets, SSH, dotfiles).
      # Stub exports an empty list so base targets evaluate without error.
      homeModules = [ ];
    };
}
