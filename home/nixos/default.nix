{ ... }:

{
  # On NixOS, home-manager activation runs as a system service without
  # access to the user's systemd D-Bus. Don't try to start user services
  # during activation — linger (set in makeNixOS) ensures they start on
  # boot instead.
  systemd.user.startServices = false;
}
