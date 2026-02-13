{ ... }:

{
  # Enable WSL support
  # wsl.defaultUser is set by the nixos-wsl entry point or flake
  wsl.enable = true;

  # Include Windows executables in PATH for seamless interop (e.g. explorer.exe,
  # code.exe). This is the primary reason to use WSL over a VM — disable if you
  # prefer strict isolation.
  wsl.interop.includePath = true;

  # Enable Start Menu launchers for GUI apps
  # Creates shortcuts in the Windows Start Menu for apps installed in WSL
  wsl.startMenuLaunchers = true;

  # Automount Windows drives at /mnt
  # Enabled by default in nixos-wsl, but being explicit here
  wsl.wslConf.automount.enabled = true;
}
