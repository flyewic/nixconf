# Dendritic NixOS Config — Docs

Documentation for building, understanding, and extending the NixOS configuration
that lives in this directory. Written for both humans and coding agents.

**Status:** implemented (on a Fedora machine without Nix). All modules are
written and statically verified; the nix-based validation steps
(`nix flake lock`, `just eval/check`) are deferred to the first NixOS boot —
see [implementation-plan.md](implementation-plan.md) Phases 8–9.

## What this is

A [dendritic](https://github.com/mightyiam/dendritic) NixOS flake: instead of
organizing configuration *by host*, every file under `src/modules/` is a
self-contained flake-parts module that registers itself by name, and hosts are
thin compositions of those named modules. File placement is the registration
mechanism — there are no manual `imports` lists tying the tree together.

## Tech choices (final)

| Concern            | Choice                                             | Docs            |
| ------------------ | -------------------------------------------------- | --------------- |
| Flake framework    | flake-parts + vic/import-tree (plain, no `den`)    | architecture.md |
| Module registry    | `flake.nixosModules.<name>`                        | architecture.md |
| $HOME management   | home-manager, **embedded** as a NixOS module       | architecture.md |
| Secrets            | sops-nix (age keys derived from SSH host keys)     | secrets.md      |
| nixpkgs channel    | `nixos-unstable` (home-manager follows)            | —               |
| Flatpaks           | nix-flatpak (declarative)                          | conventions.md  |
| Hosts              | `desktop`, `laptop` (both `x86_64-linux`)          | —               |
| Primary user       | `flye`                                             | —               |

## Doc map

| Document                                       | Purpose                                                              |
| ---------------------------------------------- | -------------------------------------------------------------------- |
| [architecture.md](architecture.md)             | How the dendritic pieces fit together + why each decision was made.  |
| [implementation-plan.md](implementation-plan.md) | Ordered build checklist, per-file specs, verification, bootstrap.  |
| [conventions.md](conventions.md)               | Rules of the repo + recipes (add a module, host, secret, flatpak…).  |
| [secrets.md](secrets.md)                       | Full sops-nix + age workflow: setup, editing, consuming, bootstrap.  |
| [enrollment.md](enrollment.md)                 | Step-by-step guide for deploying to a new device from scratch.       |
| [tooling.md](tooling.md)                       | just recipes, flake checks, QEMU VM tests, extending validation.     |
| [templates.md](templates.md)                   | Copy-paste skeletons for every file type in the config.              |

## Quick command reference

```sh
# From the repo root (this directory)

just                # list all recipes
just fmt            # format
just eval laptop    # fast validation: evaluate a host
just build desktop  # build a host's system closure
just check          # full gate: build both hosts + QEMU VM boot test
just test           # just the VM boot test
just switch         # apply to this machine

# Secrets (inside the devShell)
nix develop
just secrets        # = sops secrets/secrets.yaml
```

## For agents

Read `architecture.md` first (the two-layer module anatomy is the one concept
you must not get wrong), then `conventions.md` before touching anything under
`src/modules/`. When implementing from scratch, follow the phases in
`implementation-plan.md` in order and keep `templates.md` open on the side.
