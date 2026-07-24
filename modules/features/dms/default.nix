# DankMaterialShell — desktop shell for the niri compositor
# https://danklinux.com/docs/dankmaterialshell/nixos-flake
#
# Only the base HM module is imported (NOT the niri sub-module). The niri
# module's "includes hack" would overwrite our manually-managed config.kdl
# and dms/* files, which already have the correct include statements and
# keybinds. DMS auto-starts via its systemd user service (systemd.enable).
{ inputs, ... }:
{
  flake.nixosModules.dms =
    { config, ... }:
    {
      imports = [ inputs.dms.homeModules.dank-material-shell ];

      home-manager.users.${config.username}.programs.dank-material-shell = {
        enable = true;
        systemd.enable = true; # auto-start via systemd user service

        enableSystemMonitoring = true; # system monitoring widgets (dgop)
        enableDynamicTheming = true; # wallpaper-based theming (matugen)
        enableAudioWavelength = true; # audio visualizer (cava)

        settings = {
          theme = "dark";
          dynamicTheming = true;
        };

        session = {
          isLightMode = false;
        };

        clipboardSettings = {
          maxHistory = 25;
          maxEntrySize = 5242880; # 5 MB
          autoClearDays = 1;
          clearAtStartup = true;
          disabled = false;
          disableHistory = false;
          disablePersist = true;
        };
      };
    };
}
