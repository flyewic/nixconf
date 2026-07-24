{ ... }:
{
  flake.nixosModules.bluetooth = {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true; # GUI applet for managing Bluetooth devices
  };
}
