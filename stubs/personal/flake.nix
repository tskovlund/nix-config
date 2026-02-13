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
    };
}
