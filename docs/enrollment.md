# Device Enrollment Guide

This guide walks through deploying this NixOS configuration to a new device from scratch.

## Prerequisites

- NixOS installer USB (download from https://nixos.org/download.html)
- Internet connection
- SSH key (for sops encryption)
- The config repository cloned locally

## 1. Install NixOS (Minimal)

Boot from the NixOS installer and perform a minimal installation:

```bash
# Partition disks as needed (example: /dev/sda)
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- mkpart primary linux-swap 512MiB 2GiB
parted /dev/sda -- mkpart primary ext4 2GiB 100%

# Format partitions
mkfs.fat -F 32 -n boot /dev/sda1
mkswap -L swap /dev/sda2
mkfs.ext4 -L nixos /dev/sda3

# Mount
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/sda2

# Generate initial config
nixos-generate-config --root /mnt

# Install minimal NixOS
nixos-install
```

Reboot into the minimal NixOS installation.

## 2. Clone the Configuration

```bash
# Install git if not present
nix-shell -p git

# Clone the config
cd ~
git clone git@github.com:flyewic/nixconf.git
cd nixconf/src
```

## 3. Generate Hardware Configuration

Replace the stub hardware configuration with the real one from your system:

```bash
# Generate hardware config for this machine
sudo nixos-generate-config --show-hardware-config > modules/hosts/<hostname>/hardware-configuration.nix
```

Where `<hostname>` is either `desktop` or `laptop` (or add a new host).

## 4. Configure Host Settings

Edit `modules/hosts/<hostname>/configuration.nix`:

```nix
{
  flake.nixosModules.<hostname>Configuration = { ... }: {
    imports = with self.nixosModules; [
      core
      development
      niri
      librewolf
      discord
      # Add/remove modules as needed
      <hostname>Hardware
    ];

    networking.hostName = "<hostname>"; # Match your actual hostname
    system.stateVersion = "26.05";
  };
}
```

## 5. Set Up Sops (Secrets Management)

### 5.1 Generate Age Key from SSH Key

```bash
# Install sops and age tools
nix-shell -p sops age ssh-to-age

# Generate age public key from your SSH key
ssh-to-age < ~/.ssh/id_ed25519.pub
# Output: age1... (copy this)
```

If you don't have an SSH key yet:
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### 5.2 Update .sops.yaml

Edit `.sops.yaml` with your age public key:

```yaml
keys:
  - &admin age1... # Your personal key (from step 5.1)
  - &desktop age1... # Desktop host key (leave as placeholder for now)
  - &laptop age1... # Laptop host key (leave as placeholder for now)

creation_rules:
  - path_regex: secrets/secrets\.yaml$
    age: [*admin, *desktop, *laptop]
```

### 5.3 Create Initial Secrets

```bash
# Create the secrets file
cat > secrets/secrets.yaml << 'EOF'
# User password hash (generate with: mkpasswd -m sha-512)
user-password: "CHANGE_ME"

# Add other secrets as needed
EOF

# Encrypt the file
sops secrets/secrets.yaml
```

The file will be encrypted in place. You can edit it later with `sops secrets/secrets.yaml`.

### 5.4 Get Host SSH Key (For Future Machines)

After the first boot, each machine will have an SSH host key. Get its age public key:

```bash
# On the target machine
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Add this to `.sops.yaml` and run `sops updatekeys secrets/secrets.yaml` to allow the host to decrypt secrets.

## 6. Set User Password

Generate a password hash:

```bash
# Generate password hash
mkpasswd -m sha-512
# Enter password when prompted, copy the hash
```

Update `secrets/secrets.yaml`:

```bash
sops secrets/secrets.yaml
# Replace "CHANGE_ME" with the password hash
```

## 7. Set Timezone and Locale

Edit `modules/collections/core.nix`:

```nix
time.timeZone = "America/New_York"; # Set your timezone
i18n.defaultLocale = "en_US.UTF-8";
```

## 8. First Rebuild

```bash
# Lock the flake (downloads dependencies)
nix flake lock

# Format the config
nix fmt

# Build and switch to the new configuration
sudo nixos-rebuild switch --flake .#<hostname>
```

This will:
- Install all packages
- Set up home-manager
- Configure niri
- Install flatpaks
- Set up sops secrets
- Enable SSH, Bluetooth, etc.

## 9. Post-Install Verification

```bash
# Verify system booted correctly
systemctl --failed

# Check home-manager activation
ls -la ~/.config/

# Verify secrets are decrypted
ls -la /run/secrets/

# Check flatpaks
flatpak list

# Verify user shell
echo $SHELL # Should be fish
```

## 10. Set User Password (If Not Done via Sops)

If you didn't set up sops secrets yet:

```bash
sudo passwd flye
```

## 11. Add SSH Key to Authorized Keys

For remote access:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## 12. Final Steps

### 12.1 Test SSH Access

From another machine:
```bash
ssh flye@<hostname>
```

### 12.2 Verify Desktop Environment

```bash
# Start niri (if not already running)
niri session
```

### 12.3 Verify DMS (DankMaterialShell)

DMS auto-starts via its systemd user service. Verify it's running:

```bash
# Check if DMS is running
systemctl --user status dms.service

# Check DMS logs
journalctl --user -u dms.service -f

# If keys don't work, regenerate DMS config files:
dms setup
```

DMS files under `~/.config/niri/dms/` are auto-generated — if you change DMS
settings or add plugins, run `dms setup` to regenerate binds, colors, layout,
etc. The config ships with pre-generated copies so it works on first boot.

If DMS isn't starting, check:
- `programs.dank-material-shell.enable = true` is set in `modules/features/dms/default.nix`
- `systemd.enable = true` is set (auto-starts via user systemd service)
- The dms flake input is properly locked (`nix flake lock`)

### 12.4 Install Additional Flatpaks

Edit `modules/features/flatpak/discord.nix` (or create new files) to add more apps:

```nix
services.flatpak.packages = [
  "com.discordapp.Discord"
  "com.spotify.Client"
  # Add more here
];
```

Then rebuild:
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

## Troubleshooting

### Build Fails

```bash
# Check for syntax errors
nix flake check

# Show detailed error
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --show-trace
```

### Secrets Not Decrypting

```bash
# Verify age key is set up
cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age

# Check if key is in .sops.yaml
cat .sops.yaml

# Re-encrypt with current keys
sops updatekeys secrets/secrets.yaml
```

### Home-Manager Files Missing

```bash
# Force home-manager activation
home-manager switch --flake .#<hostname>
```

### Flatpaks Not Installing

```bash
# Check flatpak service
systemctl status flatpak-system-helper

# Manually install
flatpak install flathub com.discordapp.Discord
```

### DMS Not Starting

```bash
# Check if DMS service is enabled
systemctl --user status dms.service

# Check DMS logs
journalctl --user -u dms.service -f

# Verify DMS is in PATH
which dms

# Manually start DMS
dms
```

## Adding a New Host

1. Copy an existing host directory:
   ```bash
   cp -r modules/hosts/desktop modules/hosts/newhost
   ```

2. Update the new host's files:
   - `default.nix`: Change `desktop` to `newhost`
   - `configuration.nix`: Update hostname and imports
   - `hardware-configuration.nix`: Generate for the new machine

3. Add the new host's SSH key to `.sops.yaml`

4. Rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#newhost
   ```

## Maintenance

### Update Packages

```bash
nix flake update
sudo nixos-rebuild switch --flake .#<hostname>
```

### Clean Up Old Generations

```bash
# Using nh (recommended)
nh clean all --keep 5

# Or manually
sudo nix-collect-garbage -d
```

### Rollback

```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback
```

## Next Steps

- Customize your niri config: `modules/features/niri/config.kdl`
- Add more flatpaks as needed
- Set up additional secrets in `secrets/secrets.yaml`
- Configure per-host overrides in host configuration files

## Notes

- The niri configuration integrates with DMS (DankMaterialShell) for the launcher, clipboard manager, notifications, and other UI elements. DMS auto-starts with niri via `niri.enableSpawn = true`.
- Timezone is set to UTC by default — update it in `modules/collections/core.nix`
- User password should be set via sops secrets or manually after first boot
- SSH is enabled by default with key-only authentication
- DMS keybindings are automatically configured via `niri.enableKeybinds = true`
