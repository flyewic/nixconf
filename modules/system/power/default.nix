{ ... }:
{
  flake.nixosModules.power = {
    # Power management for laptops
    services.power-profiles-daemon.enable = true;

    # Suspend on lid close
    services.logind.lidSwitch = "suspend";

    # Enable TLP for better battery life (alternative to power-profiles-daemon)
    # services.tlp.enable = true;
  };
}
