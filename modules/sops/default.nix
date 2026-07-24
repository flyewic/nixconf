{ inputs, ... }:
{
  flake.nixosModules.sops =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops = {
        defaultSopsFile = ../../secrets/secrets.yaml;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        gnupg.sshKeyPaths = [ ]; # skip gnupg probing

        # Example (uncomment once secrets/secrets.yaml is encrypted):
        # secrets."flye/password".neededForUsers = true;
        # then: users.users.${config.username}.hashedPasswordFile =
        #   config.sops.secrets."flye/password".path;
      };
    };
}
