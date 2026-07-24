# Task runner for this flake. `just` is provided by the devShell (nix develop).
# Default host is this machine's hostname; override: just eval laptop

host := `hostname`

default:
    @just --list

# Enroll a new machine (first-time setup: hw config + sops keys + flake lock)
enroll host:
    @./scripts/enroll.sh {{host}}

# Only generate + wrap the hardware config for a host
hw host:
    @./scripts/enroll.sh {{host}} --hw-only

# Only set up sops keys (age identity + .sops.yaml + encrypted secrets file)
sops-init:
    @./scripts/enroll.sh --sops-only

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
