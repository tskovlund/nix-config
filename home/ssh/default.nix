{ ... }:

{
  programs.ssh = {
    enable = true;

    # Opt out of home-manager's SSH defaults (they just restate OpenSSH
    # built-in values and will be removed in a future release).
    enableDefaultConfig = false;

    # Include machine-local SSH config (e.g. work SSH keys, host aliases).
    # The file is optional — SSH silently ignores missing includes.
    # Include is emitted before the settings blocks, so local entries take
    # priority (SSH uses first-match-wins).
    includes = [ "~/.ssh/config.local" ];

    # Automatically add keys to ssh-agent on first use.
    # Combined with UseKeychain on macOS (set in home/darwin/), this means
    # you type your passphrase once and it's remembered across sessions.
    # Settings blocks use upstream OpenSSH directive names.
    settings."*" = {
      AddKeysToAgent = "yes";
    };
  };
}
