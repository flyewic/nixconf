# Conventions & Recipes

Rules for working in `src/`. Follow these and the config stays dendritic.

## Golden rules

1. **Every file under `modules/` is a flake-parts module.** It is auto-imported
   by import-tree; never add manual `imports` of module files by path at the
   flake level. (Exception: anything under a path component starting with `_`
   is skipped — `modules/_template.nix` uses this so it can hold placeholders.)
2. **Modules are categorized by directory:**
   - `modules/features/<name>/` — one folder per program (zellij, git, niri…)
   - `modules/system/<name>/` — infrastructure (home, sops, pipewire, nvidia…)
   - `modules/collections/` — bundles that import other modules by name
   - `modules/hosts/` — the machines

   Each registers exactly one `flake.nixosModules.<name>`; folder name ==
   registered name. Supporting files (configs, layouts, scripts) live in the
   same folder and are referenced relatively (`./config.kdl`).
   Scaffold new feature modules from `modules/_template.nix`.
3. **Compose by name, never by path.** Hosts and collections consume modules
   with `imports = with self.nixosModules; [ ... ];`. The only legal path import
   is `../../options.nix` (the dual-scope options file).
4. **User config is co-located.** home-manager is embedded; a feature module
   puts everything the package needs in `$HOME` under
   `home-manager.users.${config.username}` inside its own folder. There is no
   separate HM registry or per-host HM wiring.
5. **No `specialArgs`, no hardcoded usernames.** Shared values are options in
   `modules/options.nix` (dual scope: readable as `config.username` in both
   flake-parts and NixOS modules, because `core` re-imports it into the NixOS
   evaluation).
6. **`system` is never passed to `nixosSystem`.** `nixpkgs.hostPlatform` is set
   in the host's `hardware-configuration.nix`.
7. **Formatting:** `nix fmt` (nixfmt-rfc-style) before considering work done.

## Naming & style

- Registered names: single word or camelCase (`zed`, `cliTools`); host modules
  are `<host>Configuration` / `<host>Hardware`.
- `networking.hostName` == flake attr name == host folder name.
- Feature modules that need other features import them by name at the top of
  their own module (`niri` imports `[ pipewire fonts alacritty ]`), so hosts
  subscribe to one name and get the whole subtree.
- `system.stateVersion` is set per host; `home.stateVersion` only in
  `modules/system/home/default.nix`. Don't repeat either elsewhere.

## Recipes

### Add a new package module

```sh
mkdir modules/features/mypackage
cp modules/_template.nix modules/features/mypackage/default.nix
```

```nix
# modules/features/mypackage/default.nix
{ self, inputs, ... }:
{
  flake.nixosModules.mypackage = { pkgs, config, ... }: {
    environment.systemPackages = [ pkgs.mypackage ];
    home-manager.users.${config.username} = {
      programs.mypackage.enable = true; # if HM has a module for it
    };
  };
}
```

Then subscribe to it: add `mypackage` to a collection's import list (shared) or
to a host's `configuration.nix` (single machine). Nothing else to wire.

### Add a package with a native config file

Drop the file in the module folder and link it:

```nix
home-manager.users.${config.username}.xdg.configFile."mypackage/config.toml".source = ./config.toml;
```

This is also the fallback when home-manager has **no** typed module for the
program — e.g. `modules/features/niri/` ships a native `config.kdl` this way (verified:
no `programs.niri` in HM master). Check first; if HM later gains a module you
can migrate to typed options.

### Add a collection

```nix
# modules/collections/mycollection.nix
{ self, ... }:
{
  flake.nixosModules.mycollection = {
    imports = with self.nixosModules; [ foo bar baz ];
  };
}
```

### Add a host

Copy `modules/hosts/desktop/` to `modules/hosts/<newhost>/`, rename all three
registered names (`<newhost>` / `<newhost>Configuration` / `<newhost>Hardware`),
set `networking.hostName`, adjust subscriptions, and add the host's age
recipient to `.sops.yaml` (see secrets.md). Then paste real
`nixos-generate-config` output into `hardware-configuration.nix`.

### Add a secret

1. Encrypt the value into `secrets/secrets.yaml`:
   `nix develop` then `sops secrets/secrets.yaml`
2. Declare and consume it in the feature module that needs it:

```nix
sops.secrets."myservice/api-key" = { owner = config.username; };
# → config.sops.secrets."myservice/api-key".path  (under /run/secrets/)
```

Full workflow and per-host/per-service scoping: [secrets.md](secrets.md).

### Add a flatpak

Flatpaks are one module per app under `modules/features/flatpak/` (the support
module lives at `modules/system/flatpak/`). Add a new file:

```nix
# modules/features/flatpak/slack.nix
{ self, ... }:
{
  flake.nixosModules.slack = {
    imports = [ self.nixosModules.flatpak ]; # pulls in flatpak support
    services.flatpak.packages = [ "com.slack.Slack" ];
  };
}
```

Then subscribe to `slack` on the hosts that want it. `uninstallUnmanaged = true`
(in the support module) removes anything not declared.

### Validate changes

```sh
# From the repo root
just fmt            # format
just eval laptop    # fast: evaluate one host
just check          # full gate: builds both hosts + QEMU VM boot test
just test           # just the VM boot test
```

Details and how to extend the VM tests: [tooling.md](tooling.md).

### Override something for one host only

Set it in that host's `configuration.nix` below the imports; use `lib.mkForce`
if a feature module already sets the same option.

## Gotchas

- **Two `config`s.** The flake-parts module and the NixOS module both receive a
  `config` argument; they're different evaluations. Check which function head
  you're inside before reading `config.username` etc.
- **`username` must exist in NixOS scope.** It does, because `core` imports
  `../../options.nix` and every host imports `core`. If you build a host that
  skips `core`, you'll get "The option `username' does not exist".
- **HM option names ≠ NixOS option names ≠ upstream docs.** When using a
  `programs.*`/HM option, verify it exists in the pinned home-manager revision
  (search the HM repo at that rev, or try `nix eval`); build errors will
  pinpoint unknown options.
- **Unfree** is allowed globally via `core` (`nixpkgs.config.allowUnfree`).
  With `useGlobalPkgs`, HM inherits it. No per-host re-enabling.
- **Don't encrypt-commit secrets.yaml as plaintext.** sops-nix won't read it
  until a secret is declared, so the placeholder is safe — but encrypt it
  before adding real values (the file is git-tracked).
- **`secrets/` and `.sops.yaml` live at the flake root**, not under `modules/`,
  so import-tree never touches them. `modules/system/sops/default.nix` references them
  via `../../../`.
