{ lib, ... }:

{
  # Enable WSL support
  # wsl.defaultUser is set by the nixos-wsl entry point or flake
  wsl.enable = true;

  # Use traditional dbus-daemon instead of dbus-broker.
  # dbus-broker reloads time out frequently on WSL, causing nixos-rebuild switch
  # to hang or fail during activation. The traditional daemon handles this cleanly.
  services.dbus.implementation = lib.mkDefault "dbus";

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
