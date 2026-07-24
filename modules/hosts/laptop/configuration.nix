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
        nvidia-prime
        power
        laptopHardware
      ];

      networking.hostName = "laptop";
      system.stateVersion = "26.05";
    };
}
