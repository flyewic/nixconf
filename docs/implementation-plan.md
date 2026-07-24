# Implementation Plan

Ordered build checklist for `src/`. Follow the phases top to bottom; each phase
lists its files with enough spec to write them without further design
decisions. Full copy-paste code for the structural files is in
[templates.md](templates.md).

Legend: `[ ]` todo, `[x]` done.

---

## Phase 0 — Remove the skeleton

- [x] Delete `src/default/` (old template: `flake.nix`, `modules/parts.nix`)
- [x] Replace `src/flake.nix` (currently a template-registry flake) with the real flake

`src/flake.nix` — inputs: `nixpkgs` (nixos-unstable), `flake-parts`,
`import-tree`, `home-manager` (follows nixpkgs), `sops-nix` (follows nixpkgs),
`nix-flatpak`. Outputs: the one-liner
`inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);`.
Full code: templates.md §1.

## Phase 1 — Flake plumbing

- [x] `modules/parts.nix` — `systems = [ "x86_64-linux" ];`
- [x] `modules/options.nix` — dual-scope `username` option, default `"flye"`
      (templates.md §2)
- [x] `modules/dev.nix` — `perSystem`: `formatter = pkgs.nixfmt-rfc-style;`
      and `devShells.default` with `sops`, `age`, `ssh-to-age`, `nixfmt-rfc-style`
      (templates.md §3)

## Phase 2 — Wiring modules

- [x] `modules/home/default.nix` — registers `nixosModules.home`: imports
      `inputs.home-manager.nixosModules.home-manager`, sets `useGlobalPkgs`,
      `useUserPackages`, `backupFileExtension = "hm-backup"`, and the
      `home-manager.users.${config.username}` baseline (`home.stateVersion = "26.05"`)
      (templates.md §4)
- [x] `modules/sops/default.nix` — registers `nixosModules.sops`: imports
      `inputs.sops-nix.nixosModules.sops`, sets
      `age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`,
      `gnupg.sshKeyPaths = [ ]`, `defaultSopsFile = ../../secrets/secrets.yaml`
      (templates.md §5)

## Phase 3 — Feature modules

One folder each under `modules/`; folder name == registered name. Each is a
flake-parts module registering `flake.nixosModules.<name>`; user-level config
goes under `home-manager.users.${config.username}` in the same file.

- [x] `fish/` — NixOS `programs.fish.enable = true`;
      `users.users.${config.username}.shell = pkgs.fish;` HM `programs.fish`
      with a few `shellAbbrs`
- [x] `starship/` — HM `programs.starship.enable` + minimal `settings`
- [x] `cli-tools/` — HM `programs.{fzf,ripgrep,fd,bat,eza}` (enable + light
      options: `eza.icons = "auto"`, `eza.git = true`); fish aliases `ls`/`ll`/`cat`
- [x] `git/` — HM `programs.git` (user name/email via settings) + `programs.delta`
      with `enableGitIntegration = true`
- [x] `zellij/` — system package; HM `programs.zellij` (`settings`:
      `pane_frames = false`, theme) + a layout file `layouts/dev.kdl` linked via
      `xdg.configFile."zellij/layouts/dev.kdl".source` (demonstrates the
      "config file lives in the module folder" pattern)
- [x] `zed/` — HM `programs.zed-editor`: `enable`, `extensions = [ "nix" "toml" ]`,
      `userSettings` (theme, format-on-save, nixd as Nix LSP),
      `extraPackages = [ pkgs.nixd pkgs.nixfmt-rfc-style ]`
- [x] `alacritty/` — HM `programs.alacritty.enable` + `settings` (font, padding)
- [x] `librewolf/` — HM `programs.librewolf` if it exists in current HM
      (verify, see Risks); otherwise fallback: `home.packages = [ pkgs.librewolf ]`
      + `policies` via `programs.librewolf` replacement
- [x] `niri/` — NixOS `programs.niri.enable = true`; greetd + tuigreet login
      (`niri-session`); HM has **no** niri module (verified HM master) → ship a
      native `config.kdl` from the module folder via
      `xdg.configFile."niri/config.kdl".source`; **imports `[ pipewire fonts alacritty ]`**
- [x] `nh/` — `programs.nh` (NixOS): `enable`, `flake` (NH_FLAKE default flake
      path), `clean.enable` + `clean.extraArgs`; `nix.gc.automatic = lib.mkForce false`
      (upstream warns if nh clean and nix.gc both run)
- [x] `pipewire/` — `security.rtkit.enable`, `services.pipewire` (alsa + 32bit +
      pulse), disable pulseaudio
- [x] `fonts/` — `fonts.packages`: `nerd-fonts.jetbrains-mono`,
      `noto-fonts`, `noto-fonts-color-emoji`, `font-awesome`
- [x] `devenv/` — `home.packages = [ pkgs.devenv ]`; HM `programs.direnv` with
      `nix-direnv.enable = true`
- [x] `flatpak/` — **support module + one module per app** (flatpaks are à la
      carte, hosts subscribe to individual apps):
  - `flatpak/default.nix` → `nixosModules.flatpak`: imports
    `inputs.nix-flatpak.nixosModules.nix-flatpak`, `services.flatpak.enable`,
    flathub remote, `uninstallUnmanaged = true`, weekly auto-update
  - `flatpak/discord.nix` → `nixosModules.discord`:
    `imports = [ self.nixosModules.flatpak ]; services.flatpak.packages = [ "com.discordapp.Discord" ];`
  - `flatpak/spotify.nix` → `nixosModules.spotify`: `com.spotify.Client`
  - `flatpak/easyeffects.nix` → `nixosModules.easyeffects`: `com.github.wwmm.easyeffects`
- [x] `nvidia/` — `services.xserver.videoDrivers = [ "nvidia" ]`,
      `hardware.nvidia` (`modesetting.enable`, `open = true`,
      `package = config.boot.kernelPackages.nvidiaPackages.production`),
      `hardware.graphics.enable`

## Phase 4 — Collections

- [x] `modules/collections/core.nix` — registers `nixosModules.core`:
  - `imports = [ ../../options.nix ] ++ (with self.nixosModules; [ home sops fish starship cli-tools git nh ]);`
  - base system: `nix.settings.experimental-features = [ "nix-command" "flakes" ]`,
    `nix.gc` (weekly, `--delete-older-than 30d`), `nix.optimise.automatic = true`,
    `nixpkgs.config.allowUnfree = true`,
    `users.users.${config.username}` (isNormalUser, `wheel`, `networkmanager`),
    `networking.networkmanager.enable = true`,
    `time.timeZone = "UTC"; # TODO: set local timezone`,
    `i18n.defaultLocale = "en_US.UTF-8"`
- [x] `modules/collections/development.nix` — `imports = with self.nixosModules; [ zellij zed devenv ];`
- [x] `modules/collections/gaming.nix` — `programs.steam.enable`,
      `programs.gamemode.enable`, `hardware.graphics.enable32Bit = true`,
      `environment.systemPackages = with pkgs; [ mangohud lutris ];`

## Phase 5 — Hosts

For each of `desktop` and `laptop` (templates.md §7):

- [x] `modules/hosts/<host>/default.nix` — `nixosConfigurations.<host>` calling
      `nixosSystem` with `modules = [ self.nixosModules.<host>Configuration ]`
- [x] `modules/hosts/<host>/configuration.nix` — `nixosModules.<host>Configuration`:
  - desktop subscribes: `core development gaming nvidia niri librewolf discord spotify easyeffects desktopHardware`
  - laptop subscribes: `core development niri librewolf discord laptopHardware`
  - plus `networking.hostName`, `boot.loader.systemd-boot.enable`,
    `boot.loader.efi.canTouchEfiVariables`, `system.stateVersion = "26.05"`
- [x] `modules/hosts/<host>/hardware-configuration.nix` —
      `nixosModules.<host>Hardware` placeholder: `(modulesPath + "/installer/scan/not-detected.nix")`,
      `nixpkgs.hostPlatform = "x86_64-linux"`, stub `fileSystems."/"` +
      `# TODO: replace with nixos-generate-config output` (the stub root FS is
      required — nixpkgs asserts `fileSystems."/"` exists)

## Phase 6 — Secrets scaffolding

- [x] `src/.sops.yaml` — recipients skeleton with exact `ssh-to-age` commands in
      comments: `&admin` (flye's key), `&desktop`, `&laptop`; one creation rule
      covering `secrets/.*\.yaml$` for all three (templates.md §8)
- [x] `src/secrets/secrets.yaml` — plaintext placeholder with a header comment:
      *encrypt with `sops secrets/secrets.yaml` after filling in `.sops.yaml`,
      before declaring any `sops.secrets.*`*. One example key, commented out.
- [x] One commented consumption example in `modules/sops/default.nix`
      (`sops.secrets."flye/password"` + `hashedPasswordFile`)

## Phase 7 — Tooling & validation

- [x] `src/justfile` — task runner recipes (templates.md §9): `fmt`,
      `eval <host>`, `build <host>`, `check`, `test`, `switch`, `update`,
      `secrets`. `just` itself is added to the devShell in `modules/dev.nix`
- [x] `modules/checks.nix` — perSystem flake checks (templates.md §10):
  - `checks.build-desktop` / `checks.build-laptop` — each host's
    `config.system.build.toplevel`, so `nix flake check` builds both machines
  - `checks.vm-core` — QEMU VM boot test via `pkgs.testers.runTest`: node
    imports `core`, asserts multi-user target reached, `flye` exists with fish
    shell, HM linked `~/.config/git/config` + `~/.config/starship.toml`, user
    packages runnable
- See [tooling.md](tooling.md) for usage and how to extend the tests.

## Phase 8 — Verification

Run from `src/`. **Note:** this project was implemented on a Fedora machine
with no Nix available, so the nix-based steps are deferred to the first NixOS
boot (see Phase 9 step 0). What was done statically instead: all `.nix` files
pass a delimiter-balance check, and every HM/NixOS option used was verified
against upstream sources (HM master + nixpkgs unstable).

- [ ] `nix flake lock` (writes `flake.lock`)
- [ ] `just fmt` — tree formatted with nixfmt-rfc-style
- [ ] `nix flake show` — both `nixosConfigurations` + three `checks` listed
- [ ] `just eval desktop` / `just eval laptop` — full eval of both hosts
- [ ] `nix eval .#checks.x86_64-linux.vm-core.drvPath` — VM test evaluates
- [ ] `just build desktop` — builds (best effort, needs network)
- [x] HM/NixOS option existence verified against upstream sources:
      `programs.zellij` ✓, `programs.librewolf` ✓, `programs.zed-editor` ✓,
      `programs.git.settings` ✓, `programs.delta.enableGitIntegration` ✓,
      `programs.eza` (icons enum) ✓, `programs.direnv.nix-direnv` ✓,
      NixOS `programs.niri` ✓, NixOS `programs.nh` ✓ —
      and `programs.niri` confirmed **absent** from HM (native config.kdl used)
- [x] Static syntax check (delimiter balance) over all `.nix` files

## Phase 9 — Human bootstrap (handoff list)

Things only the user can do; call them out when implementation is done:

0. **First NixOS boot** (or any machine with Nix): run the deferred Phase 8
   steps — `nix flake lock`, `just fmt`, `just eval desktop`, then
   `just check` once you're ready for the full build + VM test
1. Generate an admin age recipient and paste the three pubkeys into `.sops.yaml`
   (commands in secrets.md §Setup)
2. `nix develop` → `sops secrets/secrets.yaml` → save to encrypt the placeholder
3. Replace both `hardware-configuration.nix` stubs with real
   `nixos-generate-config` output from each machine
4. Set `time.timeZone` in `modules/collections/core.nix`
5. First apply: `sudo nixos-rebuild switch --flake .#<host>`

## Risks & fallbacks

| Risk | Mitigation |
| --- | --- |
| `programs.librewolf` may not exist in HM | Check with `nix eval github:nix-community/home-manager#lib.evalModules ...` or simply grep the HM source (`modules/programs/librewolf.nix`); fallback to `home.packages = [ pkgs.librewolf ]` |
| HM option renames (e.g. `programs.eza.icons` became an enum) | Verify each HM option used against the HM revision pinned in `flake.lock`; build errors will name the offender |
| nix-flatpak option drift | Option names used (`remotes`, `packages`, `uninstallUnmanaged`, `update.auto`) are from nix-flatpak's README; if eval fails, check its `modules/nixos.nix` |
| VM test needs KVM | QEMU falls back to slow TCG emulation without `/dev/kvm`; the test still runs, just slowly. Skip with `just eval` if needed |
| `nixosSystem` without `system` | Handled: `nixpkgs.hostPlatform` is set in each hardware module |
| Plaintext `secrets.yaml` breaking eval | sops-nix only reads `defaultSopsFile` when a secret is actually declared; keep all `sops.secrets.*` declarations commented until the file is encrypted |
