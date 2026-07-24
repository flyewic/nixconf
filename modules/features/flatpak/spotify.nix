{ self, ... }:
{
  flake.nixosModules.spotify = {
    imports = [ self.nixosModules.flatpak ];
    services.flatpak.packages = [ "com.spotify.Client" ];
  };
}
