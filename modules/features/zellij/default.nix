{ ... }:
{
  flake.nixosModules.zellij =
    { pkgs, config, ... }:
    {
      environment.systemPackages = [ pkgs.zellij ];

      home-manager.users.${config.username} = {
        programs.zellij.enable = true;
        xdg.configFile = {
          "zellij/config.kdl".source = ./config.kdl;
          "zellij/layouts/dev.kdl".source = ./layouts/dev.kdl;
        };
      };
    };
}
