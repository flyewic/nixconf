# Secrets with sops-nix + age

End-to-end secrets workflow for this config.

## Concept

- Secrets live in `secrets/*.yaml`, encrypted with [sops](https://github.com/getsops/sops) using **age** recipients.
- Each machine decrypts at activation using an age identity **derived from its
  SSH host key** (`/etc/ssh/ssh_host_ed25519_key`) — no extra key material is
  installed or copied anywhere.
- You (the admin) edit secrets using an identity derived from **your personal
  SSH key**.
- `.sops.yaml` at the flake root controls *which recipients can decrypt which
  files* (creation rules). sops-nix wires decryption into NixOS via
  `modules/sops/default.nix`.

## One-time setup

All commands run from `src/` inside the devShell (`nix develop`), which provides
`sops`, `age`, and `ssh-to-age`.

### 1. Admin recipient (your personal key)

```sh
ssh-to-age < ~/.ssh/id_ed25519.pub
# age1...  → goes into .sops.yaml as &admin
```

If you have no SSH key yet: `ssh-keygen -t ed25519`.

### 2. Host recipients (one per machine)

On each machine (or over SSH):

```sh
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
# or remotely:
ssh root@desktop "ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub"
```

On a brand-new machine with no host key yet, either boot it once with
`services.openssh.enable = true`, or generate ahead of install and keep the
private part safe.

### 3. Fill in `.sops.yaml`

```yaml
keys:
  - &admin age1qqqq...      # flye's personal key (from step 1)
  - &desktop age1dddd...    # desktop host key (from step 2)
  - &laptop age1llll...     # laptop host key (from step 2)

creation_rules:
  # Shared secrets: decryptable everywhere + by admin
  - path_regex: secrets/secrets\.yaml$
    age: [*admin, *desktop, *laptop]

  # Per-host files: admin + that host only
  # - path_regex: secrets/desktop/[^/]+\.yaml$
  #   age: [*admin, *desktop]
```

### 4. Encrypt the placeholder

```sh
sops secrets/secrets.yaml   # opens $EDITOR; save & quit
```

The file is now encrypted in place (values become `ENC[AES256_GCM,...]`) and is
safe to commit. **Do this before declaring any `sops.secrets.*`** — sops-nix
doesn't read the file until a secret is declared, so the plaintext placeholder
is harmless, but real values must never be committed unencrypted.

## Daily workflow

| Task                    | Command / action                                             |
| ----------------------- | ------------------------------------------------------------ |
| Add/edit a secret       | `sops secrets/secrets.yaml` (uses `$EDITOR`)                 |
| View decrypted          | `sops -d secrets/secrets.yaml`                               |
| Rotate to new recipients| edit `.sops.yaml`, then `sops updatekeys secrets/secrets.yaml` |

YAML structure is flat or nested keys, e.g.:

```yaml
flye:
    password: <hashed value>
myservice:
    api-key: <token>
```

## Consuming secrets in modules

Declare in the feature module that owns the consumer:

```nix
{ inputs, ... }:
{
  flake.nixosModules.myservice = { config, ... }: {
    # declaration (paths default to /run/secrets/<name>)
    sops.secrets."myservice/api-key" = { owner = "myservice"; mode = "0400"; };

    # consumption: config.sops.secrets."myservice/api-key".path
    systemd.services.myservice.serviceConfig.EnvironmentFile =
      config.sops.secrets."myservice/api-key".path;
  };
}
```

Common patterns:

```nix
# User password (decrypted early, before users are created)
sops.secrets."flye/password".neededForUsers = true;
users.users.flye.hashedPasswordFile = config.sops.secrets."flye/password".path;

# Secret placed at a custom path for a user
sops.secrets."myservice/api-key" = {
  owner = config.username;
  path = "/home/${config.username}/.config/myservice/api-key";
  mode = "0600";
};

# Templated config file mixing several secrets
sops.templates."myservice.env".content = ''
  API_KEY=${config.sops.placeholder."myservice/api-key"}
'';
```

Note: with embedded home-manager there is **no HM sops module** wired — user
programs read secrets from `/run/secrets/...` (or a custom `path`) via the
NixOS-level declarations above. That keeps one secrets source of truth.

## Per-host and per-service scoping

Create more files when blast radius should shrink, and scope them in
`.sops.yaml`:

```
secrets/
├── secrets.yaml          # shared, all hosts
├── desktop/vault.yaml    # desktop only
└── services/forgejo.yaml # only hosts that run forgejo
```

Modules then set `sopsFile` explicitly:

```nix
sops.secrets."forgejo/admin-password" = {
  sopsFile = ../../secrets/services/forgejo.yaml;
  owner = "forgejo";
};
```

## New machine bootstrap

1. Generate/obtain the machine's host age recipient (see setup step 2).
2. Add it to `.sops.yaml` under a new anchor and to the relevant creation rules.
3. `sops updatekeys secrets/secrets.yaml` (and any other files it should read).
4. Commit; the new host can now decrypt on its next `nixos-rebuild`.

If a host loses its key (reinstall): re-derive the recipient from the new host
key and repeat steps 2–3.

## Repo wiring reference

- `.sops.yaml` — recipients + creation rules (flake root)
- `secrets/secrets.yaml` — the shared encrypted file
- `modules/sops/default.nix` — imports `inputs.sops-nix.nixosModules.sops`, sets:

```nix
sops = {
  defaultSopsFile = ../../secrets/secrets.yaml;
  age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  gnupg.sshKeyPaths = [ ]; # skip gnupg probing
};
```

- `modules/collections/core.nix` subscribes every host to the `sops` module.
