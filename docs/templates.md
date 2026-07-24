# Templates

Copy-paste skeletons for every file type in `src/`. These are
implementation-ready — the build phase mostly copies these and fills in the
marked spots. Keep [conventions.md](conventions.md) open for the rules they
follow.

## §1 `src/flake.nix`

```nix
{
  description = "flye's dendritic NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
```

## §2 `modules/parts.nix` and `modules/options.nix`

```nix
# modules/parts.nix
{
  systems = [ "x86_64-linux" ];
}
```

```nix
# modules/options.nix — dual scope: auto-imported at flake-parts level by
# import-tree, and re-imported into NixOS evaluations by collections/core.nix.
{ lib, ... }:
{
  options.username = lib.mkOption {
    type = lib.types.str;
    default = "flye";
    description = "Primary user account name.";
  };
}
```

## §3 `modules/dev.nix`

```nix
{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          sops
          age
          ssh-to-age
          nixfmt-rfc-style
        ];
      };
    };
}
```

## §4 `modules/home/default.nix`

```nix
{ inputs, ... }:
{
  flake.nixosModules.home =
    { config, ... }:
    {
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

## §5 `modules/sops/default.nix`

```nix
{ inputs, ... }:
{
  flake.nixosModules.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      gnupg.sshKeyPaths = [ ];

      # Example (uncomment once secrets/secrets.yaml is encrypted):
      # secrets."flye/password".neededForUsers = true;
      # then: users.users.<name>.hashedPasswordFile = config.sops.secrets."flye/password".path;
    };
  };
}
```

## §6 Feature modules

### Empty skeleton

```nix
# modules/<name>/default.nix
{ self, inputs, ... }:
{
  flake.nixosModules.<name> =
    { pkgs, config, lib, ... }:
    {
      # system-level config here

      home-manager.users.${config.username} = {
        # user-level (home-manager) config here
      };
    };
}
```

### Filled example — `modules/zellij/default.nix`

```nix
{ self, inputs, ... }:
{
  flake.nixosModules.zellij =
    { pkgs, config, ... }:
    {
      environment.systemPackages = [ pkgs.zellij ];

      home-manager.users.${config.username} = {
        programs.zellij = {
          enable = true;
          settings = {
            pane_frames = false;
            default_layout = "dev";
            theme = "default";
          };
        };
        xdg.configFile."zellij/layouts/dev.kdl".source = ./layouts/dev.kdl;
      };
    };
}
```

```kdl
// modules/zellij/layouts/dev.kdl
layout {
    pane split_direction="vertical" {
        pane
        pane split_direction="horizontal" {
            pane
            pane
        }
    }
    pane size=1 borderless=true {
        plugin location="zellij:status-bar"
    }
}
```

### Filled example — `modules/fish/default.nix`

```nix
{ self, inputs, ... }:
{
  flake.nixosModules.fish =
    { pkgs, config, ... }:
    {
      programs.fish.enable = true; # NixOS side: /etc/shells, vendor completions
      users.users.${config.username}.shell = pkgs.fish;

      home-manager.users.${config.username}.programs.fish = {
        enable = true;
        shellAbbrs = {
          g = "git";
          rebuild = "sudo nixos-rebuild switch --flake ~/Projects/new-nix/src";
        };
      };
    };
}
```

### Filled example — `modules/niri/default.nix` (feature importing features, native config file)

Note: HM has **no** niri module (verified against HM master), so the user
config is a native `config.kdl` shipped from the module folder:

```nix
{ self, ... }:
{
  flake.nixosModules.niri =
    { pkgs, config, ... }:
    {
      imports = with self.nixosModules; [
        pipewire
        fonts
        alacritty
      ];

      programs.niri.enable = true;

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
          user = "greeter";
        };
      };

      home-manager.users.${config.username}.xdg.configFile."niri/config.kdl".source = ./config.kdl;
    };
}
```

```kdl
// modules/niri/config.kdl — starter snippet
layout {
    gaps 16
}

binds {
    Mod+Return { spawn "alacritty"; }
    Mod+Q { close-window; }
}
```

### Filled example — `modules/nh/default.nix` (NixOS-only module)

```nix
{ ... }:
{
  flake.nixosModules.nh =
    { config, lib, ... }:
    {
      programs.nh = {
        enable = true;
        # default flake for `nh os switch` (exported as NH_FLAKE)
        flake = "/home/${config.username}/Projects/new-nix/src"; # TODO: adjust path
        clean = {
          enable = true;
          extraArgs = "--keep-since 7d --keep 5";
        };
      };

      nix.gc.automatic = lib.mkForce false; # nh clean handles GC instead
    };
}
```

### Flatpak modules — `modules/flatpak/`

Support module (imported automatically by every app module):

```nix
# modules/flatpak/default.nix
{ inputs, ... }:
{
  flake.nixosModules.flatpak = {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      uninstallUnmanaged = true;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
  };
}
```

One module per app — hosts subscribe à la carte:

```nix
# modules/flatpak/discord.nix
{ self, ... }:
{
  flake.nixosModules.discord = {
    imports = [ self.nixosModules.flatpak ];
    services.flatpak.packages = [ "com.discordapp.Discord" ];
  };
}

# modules/flatpak/spotify.nix   → com.spotify.Client
# modules/flatpak/easyeffects.nix → com.github.wwmm.easyeffects
```

### Collection — `modules/collections/development.nix`

```nix
{ self, ... }:
{
  flake.nixosModules.development = {
    imports = with self.nixosModules; [
      zellij
      zed
      devenv
    ];
  };
}
```

### Collection — `modules/collections/core.nix`

```nix
{ self, ... }:
{
  flake.nixosModules.core =
    { pkgs, config, ... }:
    {
      imports = [
        ../../options.nix # brings `username` into NixOS scope — keep first
      ]
      ++ (with self.nixosModules; [
        home
        sops
        fish
        starship
        cli-tools
        git
        nh
      ]);

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      nix.optimise.automatic = true;

      nixpkgs.config.allowUnfree = true;

      users.users.${config.username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
      };

      networking.networkmanager.enable = true;
      time.timeZone = "UTC"; # TODO: set your local timezone
      i18n.defaultLocale = "en_US.UTF-8";
    };
}
```

## §7 Host trio — `modules/hosts/desktop/`

```nix
# modules/hosts/desktop/default.nix
{ self, inputs, ... }:
{
  flake.nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [ self.nixosModules.desktopConfiguration ];
  };
}
```

```nix
# modules/hosts/desktop/configuration.nix
{ self, ... }:
{
  flake.nixosModules.desktopConfiguration =
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        core
        development
        gaming
        nvidia
        niri
        librewolf
        flatpak
        desktopHardware
      ];

      networking.hostName = "desktop";

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      system.stateVersion = "26.05";
    };
}
```

```nix
# modules/hosts/desktop/hardware-configuration.nix
# TODO: replace with the output of `nixos-generate-config` on the real machine.
{ self, ... }:
{
  flake.nixosModules.desktopHardware =
    { lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # STUB — required so evaluation succeeds; replace with real values.
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-amd" ];
    };
}
```

The laptop trio is identical with `desktop` → `laptop` and subscriptions
`[ core development niri librewolf flatpak laptopHardware ]`.

## §8 Secrets scaffolding

### `src/.sops.yaml`

```yaml
# Recipients — fill in before encrypting anything. Derive with:
#   admin:   ssh-to-age < ~/.ssh/id_ed25519.pub
#   host:    ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub   (run on the host,
#            or: ssh root@<host> "ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub")
keys:
  - &admin age1_REPLACE_ME
  - &desktop age1_REPLACE_ME
  - &laptop age1_REPLACE_ME

creation_rules:
  - path_regex: secrets/secrets\.yaml$
    age: [*admin, *desktop, *laptop]
```

### `src/secrets/secrets.yaml`

```yaml
# PLACEHOLDER — not yet encrypted.
# 1. Fill in recipients in .sops.yaml
# 2. Run: nix develop → sops secrets/secrets.yaml  (save & quit to encrypt)
# 3. Only then declare sops.secrets.* in modules.
# example-key: example-value
```

## §9 `src/justfile`

```just
# Task runner for this flake. `just` is provided by the devShell (nix develop).
# Default host is this machine's hostname; override: just eval laptop

host := `hostname`

default:
    @just --list

# Format all nix files
fmt:
    nix fmt

# Evaluate a host's full system closure (fast validation)
eval host=host:
    nix eval .#nixosConfigurations.{{ host }}.config.system.build.toplevel

# Build a host's system closure
build host=host:
    nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel

# Full gate: builds both hosts + runs the QEMU VM boot test
check:
    nix flake check

# QEMU VM boot test of the core collection
test:
    nix build .#checks.x86_64-linux.vm-core

# Apply this flake to the current machine (uses NH_FLAKE + this machine's
# hostname; nh escalates via sudo itself. On a fresh system without nh:
# sudo nixos-rebuild switch --flake .#<host>)
switch:
    nh os switch

# Update flake inputs
update:
    nix flake update

# Edit the shared secrets file (inside nix develop)
secrets:
    sops secrets/secrets.yaml
```

## §10 `modules/checks.nix`

```nix
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
```

Notes on the VM test:

- No `fileSystems`/bootloader config needed in the node — the test driver
  provides a working VM base.
- Runs without KVM but very slowly (TCG emulation); with `/dev/kvm` it's fast.
- Extend assertions or add heavier nodes (e.g. `vm-desktop`) as the config
  grows — see [tooling.md](tooling.md).
