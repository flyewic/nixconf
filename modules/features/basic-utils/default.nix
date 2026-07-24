{ self, inputs, ... }:
{
  flake.nixosModules.basic-utils =
    { pkgs, config, ... }:
    {
      environment.systemPackages = with pkgs; [
        # Clipboard (essential for Wayland)
        wl-clipboard

        # Screenshot tools (niri has binds for these)
        grim
        slurp

        # File manager
        thunar
        thunar-archive-plugin
        file-roller

        # Image viewer
        imv

        # Text editor (fallback)
        nano

        # System monitor
        btop

        # Archive tools
        unzip
        p7zip

        # Network tools
        curl
        wget
        dnsutils

        # Disk usage
        ncdu

        # Process viewer
        htop
      ];
    };
}
