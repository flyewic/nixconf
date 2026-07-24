{ ... }:
{
  flake.nixosModules.fish =
    { pkgs, config, ... }:
    {
      programs.fish.enable = true; # NixOS side: /etc/shells, vendor completions
      users.users.${config.username}.shell = pkgs.fish;

      home-manager.users.${config.username}.programs.fish = {
        enable = true;
        shellAbbrs = {
          g = "git";
          rebuild = "sudo nixos-rebuild switch --flake ~/Projects/new-nix/src";
        };
      };
    };
}
