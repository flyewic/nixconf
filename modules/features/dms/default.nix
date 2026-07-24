# DankMaterialShell - Desktop shell for niri compositor
# https://danklinux.com/docs/dankmaterialshell/nixos-flake
{ inputs, ... }:
{
  flake.nixosModules.dms =
    { config, ... }:
    {
      imports = [
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
      ];

      programs.dank-material-shell = {
        enable = true;

        # niri integration
        niri = {
          enableKeybinds = true;  # Auto-configure DMS keybindings
          enableSpawn = true;     # Auto-start DMS with niri
        };

        # Core features
        enableSystemMonitoring = true;  # System monitoring widgets (requires dgop)
        enableDynamicTheming = true;    # Wallpaper-based theming (matugen)
        enableAudioWavelength = true;   # Audio visualizer (cava)

        # Settings
        settings = {
          theme = "dark";
          dynamicTheming = true;
        };

        # Session state
        session = {
          isLightMode = false;
        };

        # Clipboard settings
        clipboardSettings = {
          maxHistory = 25;
          maxEntrySize = 5242880;  # 5MB
          autoClearDays = 1;
          clearAtStartup = true;
          disabled = false;
          disableHistory = false;
          disablePersist = true;
        };
      };
    };
}
