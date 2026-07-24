{ ... }:
{
  flake.nixosModules.devenv =
    { pkgs, config, ... }:
    {
      home-manager.users.${config.username} = {
        home.packages = [ pkgs.devenv ];
        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
      };
    };
}
