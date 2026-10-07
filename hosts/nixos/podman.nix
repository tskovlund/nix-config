{ pkgs, username, ... }:

{
  # Daemonless container runtime. dockerCompat provides `docker` CLI alias
  # and socket, needed for tools like Testcontainers that expect Docker.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  # The docker-compat socket is root:podman 0660; without the group the
  # user's Docker clients (Testcontainers, docker-compose) get EACCES.
  users.users.${username}.extraGroups = [ "podman" ];

  # Docker Compose CLI plugin, wired through the Podman docker-compat socket.
  environment.systemPackages = [ pkgs.docker-compose ];
}
