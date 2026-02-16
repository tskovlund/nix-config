{ ... }:

{
  # Daemonless container runtime. dockerCompat provides `docker` CLI alias
  # and socket, needed for tools like Testcontainers that expect Docker.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
}
