{ ... }:
{
  flake.nixosModules.cli-tools =
    { config, ... }:
    {
      home-manager.users.${config.username}.programs = {
        fzf.enable = true;
        ripgrep.enable = true;
        fd.enable = true;
        bat.enable = true;

        # eza's HM module already aliases ls/ll/la/lt/lla via shell integration
        eza = {
          enable = true;
          icons = "auto";
          git = true;
        };

        fish.shellAliases = {
          cat = "bat";
        };
      };
    };
}
