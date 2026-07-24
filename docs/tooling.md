# Tooling & Validation

How to work on this config day to day, and how to validate it **without
touching the machine being configured**.

## Task runner: just

A `justfile` sits next to `src/flake.nix`; `just` itself is provided by the
devShell (`nix develop`). Run `just` with no arguments to list recipes.

| Recipe               | What it does                                                        |
| -------------------- | ------------------------------------------------------------------- |
| `just fmt`           | `nix fmt` (nixfmt-rfc-style)                                        |
| `just eval <host>`   | Evaluate a host's full system closure — fast validation             |
| `just build <host>`  | Build a host's system closure into `./result`                       |
| `just check`         | `nix flake check` — builds **both** hosts + the VM boot test        |
| `just test`          | Build only the QEMU VM boot test (`checks.vm-core`)                 |
| `just switch`        | `nh os switch` — applies to this machine (NH_FLAKE + hostname)      |
| `just update`        | `nix flake update`                                                  |
| `just secrets`       | Edit `secrets/secrets.yaml` with sops                               |

`<host>` defaults to the machine's hostname (`just eval` on `desktop` evaluates
`desktop`); override by passing it explicitly: `just eval laptop`. `just switch`
takes no host argument — it relies on the convention that flake attr name ==
`networking.hostName` == actual hostname.

## Validation layers

Use the cheapest layer that answers your question:

1. **`just fmt`** — syntax/formatting.
2. **`just eval <host>`** — evaluates every module of a host (including the
   embedded home-manager config) without building anything. Catches unknown
   options, type errors, infinite recursion. Seconds.
3. **`just build <host>`** — builds the whole system closure. Catches missing
   dependencies, broken overrides, hash mismatches. Minutes (first time).
4. **`just check`** — the full gate: builds both hosts **and** runs the VM
   boot test. This is what to run before considering a change done.
5. **`just test`** — boots the config in QEMU and asserts it works (below).

## Flake checks (`modules/checks.nix`)

```nix
checks = {
  # Each host's toplevel as a buildable check — `nix flake check` builds them.
  build-desktop = self.nixosConfigurations.desktop.config.system.build.toplevel;
  build-laptop  = self.nixosConfigurations.laptop.config.system.build.toplevel;

  # QEMU VM boot test of the core collection.
  vm-core = pkgs.testers.runTest { ... };
}
```

## QEMU VM tests

`pkgs.testers.runTest` (the NixOS test driver) boots real QEMU VMs running the
actual configuration, then executes a Python `testScript` against them. This is
the native nixpkgs mechanism for answering *"does this configuration boot and
work?"* — a NixOS system **cannot** run inside podman/docker (no systemd as
PID 1, no real initrd/kernel), which is why containers are not used here.

`vm-core` boots a node importing the `core` collection and asserts:

```python
machine.wait_for_unit("multi-user.target")                       # system boots
machine.succeed("getent passwd flye | grep -q fish")             # user + login shell
machine.succeed("su - flye -c 'git --version'")                  # HM user packages on PATH
machine.succeed("su - flye -c 'test -f ~/.config/git/config'")   # HM linked dotfiles
machine.succeed("su - flye -c 'test -f ~/.config/starship.toml'")
```

Notes:

- The test driver provides the VM's base filesystem/bootloader — nodes don't
  need `fileSystems` or `boot.loader` config.
- **KVM:** with `/dev/kvm` access the test runs in ~a minute. Without it QEMU
  falls back to TCG emulation — it still passes, just much slower.
- Only `core` is imported, keeping the test fast and free of graphical/network
  dependencies (flatpaks install at activation from the network, so flatpak
  modules don't belong in offline VM tests).

### Running and debugging

```sh
just test                                    # build & run headless
nix build .#checks.x86_64-linux.vm-core     # same thing
nix run .#checks.x86_64-linux.vm-core.driverInteractive
# ↑ boots the VM interactively with a Python REPL — poke around with
#   machine.shell_interact(), run commands, inspect services
```

### Extending

Add another node or another check in `modules/checks.nix`. Example — a heavier
graphical smoke test:

```nix
vm-desktop = pkgs.testers.runTest {
  name = "vm-desktop";
  nodes.machine = { ... }: {
    imports = with self.nixosModules; [ core development niri ];
    networking.hostName = "vm-desktop";
    system.stateVersion = "26.05";
    # skip modules that need real hardware (nvidia) or network (flatpak apps)
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("greetd.service")
    machine.succeed("su - flye -c 'test -f ~/.config/niri/config.kdl'")
  '';
};
```

Guidelines for writing more tests:

- Import feature modules by name, exactly like hosts do — the test then
  validates the same composition a real machine gets.
- Skip hardware-dependent modules (`nvidia`) and network-dependent ones
  (`flatpak` apps install at activation; the sandboxed test has no network).
- Keep one cheap `vm-core`-style test fast enough to run on every change;
  gate heavier graphical tests behind separate check names.
- The `testScript` API (`wait_for_unit`, `succeed`, `fail`, `wait_for_file`,
  `screenshot`, …) is documented in the NixOS manual, "Writing NixOS Tests".
