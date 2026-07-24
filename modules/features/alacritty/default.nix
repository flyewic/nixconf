{ ... }:
{
  flake.nixosModules.alacritty =
    { config, ... }:
    {
      # Alacritty config shipped as native TOML files (complex imports + theme)
      home-manager.users.${config.username}.xdg.configFile = {
        "alacritty/alacritty.toml".source = ./alacritty.toml;
        "alacritty/dank-theme.toml".source = ./dank-theme.toml;
      };
    };
}
