{ inputs, ... }:
{
  flake.nixosModules.home =
    { config, ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        users.${config.username} = {
          home.username = config.username;
          home.homeDirectory = "/home/${config.username}";
          home.stateVersion = "26.05";
          programs.home-manager.enable = true;
        };
      };
    };
}
