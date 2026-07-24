{ pkgs, ... }:
{
  flake.nixosModules.basic-utils = {
    environment.systemPackages = with pkgs; [
      # Clipboard (essential for Wayland)
      wl-clipboard

      # Screenshot tools (niri has binds for these)
      grim # screenshot tool
      slurp # region selector

      # File manager
      thunar
      thunar-archive-plugin
      file-roller # archive manager

      # Image viewer
      imv

      # Document viewer
      zathara

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
