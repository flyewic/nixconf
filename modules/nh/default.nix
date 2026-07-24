# nh — nicer CLI for nix/nixos/home-manager (https://github.com/nix-community/nh)
# Replaces nix.gc with `nh clean` (upstream warns if both are enabled).
{ ... }:
{
  flake.nixosModules.nh =
    { config, lib, ... }:
    {
      programs.nh = {
        enable = true;
        # Default flake for `nh os switch` etc. (exported as NH_FLAKE).
        # TODO: adjust to wherever this repo lives on the machine.
        flake = "/home/${config.username}/Projects/new-nix/src";
        clean = {
          enable = true;
          extraArgs = "--keep-since 7d --keep 5";
        };
      };

      nix.gc.automatic = lib.mkForce false; # nh clean handles GC instead
    };
}
