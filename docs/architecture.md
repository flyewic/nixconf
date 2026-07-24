# Architecture

How the config fits together. Read this before writing any code in `src/`.

## Big picture

```
src/
├── flake.nix                 # inputs + ONE line of outputs
├── justfile                  # task runner (just) — fmt, eval, build, check, test, switch…
├── .sops.yaml                # age recipients + creation rules for sops
├── secrets/
│   └── secrets.yaml          # sops-encrypted secrets (single shared file)
└── modules/                  # EVERYTHING below is auto-imported by import-tree
    ├── parts.nix             #   systems list (flake-parts)
    ├── options.nix           #   shared values (dual-scope, see below)
    ├── dev.nix               #   devShell + formatter (perSystem)
    ├── checks.nix            #   flake checks: host builds + QEMU VM boot test
    ├── _template.nix         #   skeleton for new modules (skipped by import-tree)
    ├── system/               #   infrastructure: home, sops, nh, pipewire, fonts, nvidia, flatpak
    ├── features/             #   one folder per program: zellij, fish, git, zed, alacritty, niri, …
    │   └── flatpak/          #   flatpak apps: discord, spotify, easyeffects
    ├── collections/          #   bundles: core, development, gaming
    └── hosts/                #   desktop/ + laptop/ (3 files each, see below)
```

The entire flake `outputs` is one line:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

`import-tree` recursively imports every `.nix` file under `modules/` as a
flake-parts module. Adding/removing a file adds/removes it from evaluation —
**file placement is registration**. Paths with a component starting with `_`
are skipped (use that for assets that must not be treated as modules).

## The two-layer module anatomy (the key concept)

Every file in `modules/` is a **flake-parts module** (outer layer). Its only
job is to register things into flake outputs — almost always a named NixOS
module under `flake.nixosModules.<name>` (inner layer):

```nix
# modules/features/zellij/default.nix
{ self, inputs, ... }:                    # ← flake-parts scope (args: self, inputs, config, lib, ...)
{
  flake.nixosModules.zellij =             # ← the registered name (must match the folder name)
    { pkgs, config, lib, ... }:           # ← NixOS scope (a plain NixOS module)
    {
      # system-level configuration
      environment.systemPackages = [ pkgs.zellij ];

      # user-level configuration (embedded home-manager, see below)
      home-manager.users.${config.username} = {
        programs.zellij.enable = true;
      };
    };
}
```

Two different `config`s exist: the flake-parts one (outer) and the NixOS one
(inner). Getting confused about which scope you're in is the #1 source of
errors — check the function head.

## The registry and composition

Nothing is imported by path between modules. Instead:

- **Feature modules** (`modules/features/<name>/`) register
  `flake.nixosModules.<name>`. One folder per program, folder name ==
  registered name.
- **System modules** (`modules/system/<name>/`) are the same shape for
  infrastructure concerns (home-manager wiring, secrets, audio, drivers).
- **Collections** (`modules/collections/*.nix`) are feature modules whose whole
  content is `imports = with self.nixosModules; [ ... ];` — named bundles.
- **Hosts** (`modules/hosts/<host>/`) compose collections and features:

```nix
# modules/hosts/desktop/configuration.nix
{ self, ... }:
{
  flake.nixosModules.desktopConfiguration = { pkgs, ... }: {
    imports = with self.nixosModules; [
      core development gaming nvidia niri librewolf flatpak desktopHardware
    ];
    networking.hostName = "desktop";
    system.stateVersion = "26.05";
  };
}
```

```nix
# modules/hosts/desktop/default.nix — the nixosSystem call
{ self, inputs, ... }:
{
  flake.nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [ self.nixosModules.desktopConfiguration ];
  };
}
```

This gives the subscription model: *"desktop subscribes to core, development,
gaming, nvidia; laptop subscribes to core, development."* Feature modules may
also import other features (e.g. `niri` imports `pipewire`, `fonts`,
`alacritty`) so subscription lists stay short.

Hosts are a 3-file split:

| File                        | Registers                              | Content                                |
| --------------------------- | -------------------------------------- | -------------------------------------- |
| `default.nix`               | `nixosConfigurations.<host>`           | the `nixosSystem` call (3 lines)       |
| `configuration.nix`         | `nixosModules.<host>Configuration`     | module subscriptions + host settings   |
| `hardware-configuration.nix`| `nixosModules.<host>Hardware`          | `nixos-generate-config` output         |

Note: `nixosSystem` is **not** given `system =`; instead
`nixpkgs.hostPlatform = "x86_64-linux"` is set inside the hardware module
(supported since nixpkgs 24.11).

## Embedded home-manager

home-manager is a NixOS module, not a standalone flake output. Wiring lives in
exactly one place, `modules/system/home/default.nix`:

```nix
{ inputs, ... }:
{
  flake.nixosModules.home = { config, ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      users.${config.username} = {
        home.username = config.username;
        home.homeDirectory = "/home/${config.username}";
        home.stateVersion = "26.05";
        programs.home-manager.enable = true;
      };
    };
  };
}
```

Consequences:

- One `nixos-rebuild switch` applies system + dotfiles together.
- Feature modules co-locate system and user config: anything a package needs in
  `$HOME` goes under `home-manager.users.${config.username}` **inside the same
  module folder** (see the zellij example above). There is no separate
  `homeModules` registry.
- `useGlobalPkgs` means HM shares the NixOS pkgs instance, so
  `nixpkgs.config.allowUnfree = true` (set in `core`) covers HM too.

## Sharing data without specialArgs: the dual-scope `options.nix`

`modules/options.nix` declares a plain option that is valid in **both** module
systems:

```nix
{ lib, ... }:
{
  options.username = lib.mkOption {
    type = lib.types.str;
    default = "flye";
    description = "Primary user account name.";
  };
}
```

- import-tree loads it at **flake-parts scope** → readable as `config.username`
  in any flake-parts module.
- `modules/collections/core.nix` re-imports it **into the NixOS evaluation**
  (`imports = [ ../../options.nix ]`) → readable as `config.username` in any
  NixOS module (this is what `home-manager.users.${config.username}` uses).

Every host imports `core`, so the option is always defined in every NixOS
evaluation. If a new shared value is ever needed (e.g. timezone, email), add it
to this file — never thread values through `specialArgs`.

## Secrets architecture

sops-nix, with **age identities derived from each host's SSH host key**
(`/etc/ssh/ssh_host_ed25519_key`) — no separate key files to protect or copy.

- `.sops.yaml` at the flake root lists recipients: one **admin** key (derived
  from flye's personal SSH key, used to edit secrets) plus one key **per host**
  (so each machine can decrypt).
- `modules/system/sops/default.nix` imports `sops-nix`, sets
  `sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]` and
  `sops.defaultSopsFile = ../../secrets/secrets.yaml`.
- Feature modules declare secrets with `sops.secrets.<name> = { ... };` and
  consume them via `config.sops.secrets.<name>.path` (decrypted to
  `/run/secrets/` at activation).

Full workflow: [secrets.md](secrets.md).

## Flatpaks

Declarative via the `nix-flatpak` input, and split like everything else — a
**support module** plus **one module per app**:

```
modules/system/flatpak/default.nix   # nixosModules.flatpak — nix-flatpak import, service, flathub remote
modules/features/flatpak/
├── discord.nix        # nixosModules.discord — services.flatpak.packages += Discord
├── spotify.nix        # nixosModules.spotify
└── easyeffects.nix    # nixosModules.easyeffects
```

Each app module imports the support module (`imports = [ self.nixosModules.flatpak ];`),
so a host subscribes to exactly the apps it wants and flatpak support comes
along automatically — not every host gets Spotify, not every host gets
EasyEffects. `uninstallUnmanaged = true` keeps machines free of anything not
declared.

## Tooling & validation

- **Task runner:** `just` (a `justfile` lives next to `src/flake.nix`, and
  `just` is in the devShell). Recipes wrap the common commands: `just fmt`,
  `just eval laptop`, `just build desktop`, `just check`, `just test`,
  `just switch`, `just secrets`, `just update`.
- **Off-host validation** happens without touching the machine being
  configured, via flake checks (`modules/checks.nix`):
  - `checks.build-desktop` / `checks.build-laptop` — each host's full system
    closure as a buildable check (`nix flake check` builds them).
  - `checks.vm-core` — a **QEMU VM test** (`pkgs.testers.runTest`) that boots a
    VM importing the `core` collection and asserts the system comes up: user
    exists with fish shell, home-manager activation linked the dotfiles, user
    packages work.
- Why not podman/docker? A NixOS configuration is not containerizable — there
  is no way to run systemd-as-PID-1 NixOS meaningfully inside a container.
  QEMU VM tests are the native nixpkgs mechanism for "does this configuration
  actually boot and work". Details: [tooling.md](tooling.md).

## Decision record

| Decision                    | Chosen                          | Alternative considered           | Why |
| --------------------------- | ------------------------------- | -------------------------------- | --- |
| Framework                   | plain flake-parts + import-tree | `den` (danielgafni example)      | Explicit, no magic, easy to debug; den's aspect DAG is overkill for 2 hosts/1 user |
| $HOME                       | home-manager embedded           | hjem / hjem-rum, standalone HM   | HM has typed modules for almost everything on the list (zellij, zed, librewolf, eza, bat…) — hjem-rum covers almost none and self-describes as not ready to replace HM; embedded = single rebuild command. Exception: **niri** has no HM module (verified against HM master) — its user config ships as a native `config.kdl` from the module folder |
| Secrets                     | sops-nix                        | agenix                           | One YAML holds many secrets, per-host creation rules, templates; matches 2 of the examples |
| Module shape                | one folder per package, co-located HM | separate `homeModules` registry | Simplest subscription model; refactorable later if standalone HM is ever wanted |
| Data sharing                | dual-scope options (`options.nix`) | `specialArgs`                  | Dendritic convention; works in both module systems |
| Channel                     | `nixos-unstable`                | `nixos-26.05`                    | niri/zed move fast; all examples use unstable |
| Flatpaks                    | nix-flatpak, one module per app | single flatpak module with a package list | hosts pick apps à la carte like any other feature |
| Task runner                 | `just` (`src/justfile`)         | make, nushell scripts            | clean syntax, single binary, provided by the devShell |
| OS CLI                      | `nh` (`programs.nh`, in `core`) | plain `nixos-rebuild` + `nix.gc` | nicer UX/output; `nh clean` replaces `nix.gc` (upstream warns if both run) — the module force-disables `nix.gc.automatic` |
| Off-host validation         | `nix flake check` + QEMU VM tests (`pkgs.testers.runTest`) | podman container | a NixOS config can't run in a container; VM tests boot the real configuration and are the native nixpkgs test mechanism |
