{ self, ... }:
{
  flake.nixosModules.core =
    { pkgs, config, ... }:
    {
      imports = [
        ../../options.nix # brings `username` into NixOS scope — keep first
      ]
      ++ (with self.nixosModules; [
        home
        sops
        fish
        starship
        cli-tools
        git
        nh
        network
        bluetooth
        ssh
        basic-utils
        boot
      ]);

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      nix.optimise.automatic = true;

      nixpkgs.config.allowUnfree = true;

      users.users.${config.username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
      };

      time.timeZone = "UTC"; # TODO: set your local timezone
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";
    };
}
