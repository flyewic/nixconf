{ self, ... }:
{
  flake.nixosModules.easyeffects = {
    imports = [ self.nixosModules.flatpak ];
    services.flatpak.packages = [ "com.github.wwmm.easyeffects" ];
  };
}
