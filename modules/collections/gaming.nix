{ ... }:
{
  flake.nixosModules.gaming =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
      };
      programs.gamemode.enable = true;
      hardware.graphics.enable32Bit = true;
      environment.systemPackages = with pkgs; [
        mangohud
        lutris
      ];
    };
}
