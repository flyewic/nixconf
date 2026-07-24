{ ... }:
{
  flake.nixosModules.ssh = {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false; # key-only auth
        PermitRootLogin = "no";
      };
    };
    # Allow SSH through firewall
    networking.firewall.allowedTCPPorts = [ 22 ];
  };
}
