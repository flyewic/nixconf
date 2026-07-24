{ self, ... }:
{
  flake.nixosModules.discord = {
    imports = [ self.nixosModules.flatpak ];
    services.flatpak.packages = [ "com.discordapp.Discord" ];
  };
}
