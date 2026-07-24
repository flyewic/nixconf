{ ... }:
{
  flake.nixosModules.zellij =
    { pkgs, config, ... }:
    {
      environment.systemPackages = [ pkgs.zellij ];

      home-manager.users.${config.username} = {
        programs.zellij = {
          enable = true;
          settings = {
            # Main config shipped as native config.kdl (too large for HM settings attrset)
            # See ./config.kdl for the full configuration
          };
        };
        xdg.configFile = {
          "zellij/config.kdl".source = ./config.kdl;
          "zellij/layouts/dev.kdl".source = ./layouts/dev.kdl;
        };
      };
    };
}
