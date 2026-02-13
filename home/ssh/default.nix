{ ... }:

{
  programs.ssh = {
    enable = true;

    # Opt out of home-manager's SSH defaults (they just restate OpenSSH
    # built-in values and will be removed in a future release).
    enableDefaultConfig = false;

    # Automatically add keys to ssh-agent on first use.
    # Combined with UseKeychain on macOS (set in home/darwin/), this means
    # you type your passphrase once and it's remembered across sessions.
    matchBlocks."*" = {
      addKeysToAgent = "yes";
    };
  };
}
