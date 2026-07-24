# Dual scope: auto-imported at flake-parts level by import-tree, and
# re-imported into NixOS evaluations by collections/core.nix. This makes
# `config.username` readable in both module systems — never hardcode it.
{ lib, ... }:
{
  options.username = lib.mkOption {
    type = lib.types.str;
    default = "flye";
    description = "Primary user account name.";
  };
}
