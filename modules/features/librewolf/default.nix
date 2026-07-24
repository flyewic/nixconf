{ ... }:
{
  flake.nixosModules.librewolf =
    { config, ... }:
    {
      home-manager.users.${config.username}.programs.librewolf = {
        enable = true;
        settings = {
          "webgl.disabled" = false;
          "privacy.resistFingerprinting" = false;
        };
      };
    };
}
