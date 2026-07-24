# niri — NixOS provides the compositor (programs.niri), but home-manager has
# no niri module (checked HM master), so the user config is a native
# config.kdl shipped from this folder. The dms/ subdirectory contains
# additional KDL files included by the main config (DMS desktop shell).
{ self, ... }:
{
  flake.nixosModules.niri =
    { pkgs, config, ... }:
    {
      imports = with self.nixosModules; [
        pipewire
        fonts
        alacritty
        dms  # DankMaterialShell integration
      ];

      programs.niri.enable = true;

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
          user = "greeter";
        };
      };

      home-manager.users.${config.username}.xdg.configFile = {
        "niri/config.kdl".source = ./config.kdl;
        "niri/dms".source = ./dms;
      };
    };
}
