{ ... }:

{
  # Enable WSL support
  # wsl.defaultUser is set by the nixos-wsl entry point or flake
  wsl.enable = true;

  # Enable WSL interop — allows running Windows executables from WSL
  # includePath = true adds Windows executables to PATH
  wsl.interop.includePath = true;

  # Enable Start Menu launchers for GUI apps
  # Creates shortcuts in the Windows Start Menu for apps installed in WSL
  wsl.startMenuLaunchers = true;

  # Automount Windows drives at /mnt
  # Enabled by default in nixos-wsl, but being explicit here
  wsl.wslConf.automount.enabled = true;
}
