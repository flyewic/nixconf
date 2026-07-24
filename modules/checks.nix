{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        # `nix flake check` builds both machines' full system closures.
        build-desktop = self.nixosConfigurations.desktop.config.system.build.toplevel;
        build-laptop = self.nixosConfigurations.laptop.config.system.build.toplevel;

        # QEMU VM boot test: boots a machine with the `core` collection and
        # asserts the system actually comes up for the user.
        vm-core = pkgs.testers.runTest {
          name = "vm-core";

          nodes.machine =
            { ... }:
            {
              imports = with self.nixosModules; [ core ];
              networking.hostName = "vm-core";
              system.stateVersion = "26.05";
            };

          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.succeed("getent passwd flye | grep -q fish")
            machine.succeed("su - flye -c 'git --version'")
            machine.succeed("su - flye -c 'test -f ~/.config/git/config'")
            machine.succeed("su - flye -c 'test -f ~/.config/starship.toml'")
          '';
        };
      };
    };
}
