{ self, ... }:
{
  flake.nixosModules.desktopConfiguration =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        core
        development
        gaming
        nvidia
        niri
        librewolf
        discord
        spotify
        easyeffects
        desktopHardware
      ];

      networking.hostName = "desktop";
      system.stateVersion = "26.05";
    };
}
