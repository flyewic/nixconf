{ self, ... }:
{
  flake.nixosModules.development = {
    imports = with self.nixosModules; [
      zellij
      zed
      devenv
    ];
  };
}
