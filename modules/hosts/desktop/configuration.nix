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

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      system.stateVersion = "26.05";
    };
}
