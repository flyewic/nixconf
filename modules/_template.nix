# Template for a new feature module.
#
# This file is NOT evaluated: the `_` prefix makes import-tree skip it
# (see docs/architecture.md). Copy it to create a real module:
#
#   1. mkdir modules/features/<name>
#      cp modules/_template.nix modules/features/<name>/default.nix
#   2. Replace every `<name>` (folder name must equal the registered name).
#   3. Subscribe: add `<name>` to a collection in modules/collections/
#      or to a host in modules/hosts/<host>/configuration.nix.
#
# For infrastructure/system modules use modules/system/<name>/ instead.
# More shapes (collections, hosts, perSystem packages): docs/templates.md
{ self, inputs, ... }:
{
  flake.nixosModules.<name> =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      # ── system-level configuration ────────────────────────────────
      environment.systemPackages = [ pkgs.<name> ];

      # ── user-level configuration (embedded home-manager) ──────────
      home-manager.users.${config.username} = {
        # Option A: typed home-manager module (verify it exists first:
        # https://nix-community.github.io/home-manager/options.xhtml)
        # programs.<name> = {
        #   enable = true;
        #   settings = { };
        # };

        # Option B: native config file shipped from this folder
        # xdg.configFile."<name>/config.toml".source = ./config.toml;
      };
    };
}
