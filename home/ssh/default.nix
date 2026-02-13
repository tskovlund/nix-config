{ ... }:

{
  programs.ssh = {
    enable = true;

    # Automatically add keys to ssh-agent on first use.
    # Combined with UseKeychain on macOS (set in home/darwin/), this means
    # you type your passphrase once and it's remembered across sessions.
    matchBlocks."*" = {
      addKeysToAgent = "yes";
    };
  };
}
