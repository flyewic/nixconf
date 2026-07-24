{ ... }:
{
  flake.nixosModules.git =
    { config, ... }:
    {
      home-manager.users.${config.username}.programs = {
        git = {
          enable = true;
          settings = {
            user = {
              name = "flye";
              email = "flyewic@gmail.com";
            };
            core = {
              autocrlf = "input";
            };
            init = {
              defaultBranch = "main";
            };
            credential = {
              helper = "store";
            };
          };
        };

        delta = {
          enable = true;
          enableGitIntegration = true;
          options = {
            navigate = true;
            side-by-side = true;
            line-numbers = true;
          };
        };
      };
    };
}
