{ pkgs, ... }:

{
  # Daemonless container runtime. dockerCompat provides `docker` CLI alias
  # and socket, needed for tools like Testcontainers that expect Docker.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  # Docker Compose CLI plugin, wired through the Podman docker-compat socket.
  environment.systemPackages = [ pkgs.docker-compose ];
}
