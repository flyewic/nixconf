{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          sops
          age
          ssh-to-age
          nixfmt-rfc-style
        ];
      };
    };
}
