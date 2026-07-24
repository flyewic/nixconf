{ self, ... }:
{
  flake.nixosModules.laptopConfiguration =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        core
        development
        niri
        librewolf
        discord
        laptopHardware
      ];

      networking.hostName = "laptop";

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      system.stateVersion = "26.05";
    };
}
