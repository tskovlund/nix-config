# Tailscale mesh VPN.
#
# Creates a private WireGuard-based network between all devices.
# After authentication, SSH and internal services (Prometheus, Loki, etc.)
# are accessible via Tailscale IPs without exposing them to the internet.
#
# Post-deploy setup (first time only):
#   1. Create Tailscale account at https://login.tailscale.com
#   2. Deploy: make deploy-miles
#   3. SSH to miles: tailscale up
#   4. Authenticate via the browser link
#   5. Verify: tailscale status
#   6. From MacBook: ssh root@<tailscale-ip>
#   7. Once verified, remove port 22 from networking.firewall.allowedTCPPorts
{ ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true; # UDP 41641 for WireGuard
  };

  # Trust the Tailscale interface — allows SSH, Prometheus, Loki, etc.
  # via Tailscale IPs without opening them to the public internet.
  # Safe because only Thomas's devices are on the tailnet.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
