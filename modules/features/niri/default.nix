# niri — NixOS provides the compositor (programs.niri), but home-manager has
# no niri module (checked HM master), so the user config is a native
# config.kdl shipped from this folder. The dms/ subdirectory contains
# additional KDL files included by the main config (DMS desktop shell).
#
# Per-host outputs: dms/outputs.kdl is selected based on networking.hostName
# so desktop gets the 3-monitor config and laptop gets the single-screen one.
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

      home-manager.users.${config.username}.xdg.configFile = let
        host = config.networking.hostName;
      in {
        "niri/config.kdl".source = ./config.kdl;

        # DMS generated includes — shared across hosts
        "niri/dms/colors.kdl".source       = ./dms/colors.kdl;
        "niri/dms/layout.kdl".source       = ./dms/layout.kdl;
        "niri/dms/alttab.kdl".source       = ./dms/alttab.kdl;
        "niri/dms/binds.kdl".source        = ./dms/binds.kdl;
        "niri/dms/cursor.kdl".source       = ./dms/cursor.kdl;
        "niri/dms/windowrules.kdl".source  = ./dms/windowrules.kdl;
        "niri/dms/wpblur.kdl".source       = ./dms/wpblur.kdl;

        # Per-host outputs
        "niri/dms/outputs.kdl".source =
          if host == "desktop"
          then ./dms/outputs-desktop.kdl
          else ./dms/outputs-laptop.kdl;
      };
    };
}
