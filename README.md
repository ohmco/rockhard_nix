# 🪨 rockhard_nix

A rockhard, rock solid NixOS fleet — **flake-parts + Colmena + Podman**.

## Architecture

```
                 ┌─────────────────┐
                 │  Your Laptop    │
                 │  (colmena CLI)  │
                 └────────┬────────┘
                          │ SSH
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ macmini  │ │  (host2) │ │  (host3) │
        │ NixOS    │ │  NixOS   │ │  NixOS   │
        │ Podman   │ │  Podman  │ │  Podman  │
        └──────────┘ └──────────┘ └──────────┘
              @home-lab    @cloud      @edge
```

## Repository Structure

```
rockhard_nix/
├── flake.nix              # Entry point — flake-parts mkFlake
├── parts/
│   ├── colmena.nix        # Fleet deployment config
│   ├── dev-shell.nix      # Dev shell with colmena CLI
│   └── images.nix         # Nix-built OCI container images
├── hosts/
│   ├── macmini/           # Mac Mini 5,1 (2011)
│   │   ├── default.nix    # Host-specific config
│   │   └── hardware.nix   # Generated hardware config
│   └── _template/         # Copy this for new machines
├── modules/
│   ├── base.nix           # Nix settings, packages, locale
│   ├── podman.nix         # Podman + container tooling
│   ├── networking.nix     # SSH, firewall, mDNS
│   └── users.nix          # User accounts + SSH keys
└── containers/
    └── README.md          # Guide for Nix-built OCI images
```

## Prerequisites

- A USB drive (8GB+)
- The target machine (Mac Mini 5,1 or any x86_64 box)
- Wired ethernet recommended for install

---

## Phase 1: Prepare the NixOS USB Installer

On your current machine (macOS or Linux):

```sh
# Download the NixOS minimal ISO
curl -L -o ~/Downloads/nixos-minimal.iso \
  https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso
```

### Write to USB (macOS)

```sh
diskutil list                               # find your USB disk
diskutil unmountDisk /dev/diskN             # unmount it
sudo dd if=~/Downloads/nixos-minimal.iso of=/dev/rdiskN bs=4m status=progress
```

### Write to USB (Linux)

```sh
lsblk                                       # find your USB disk
sudo dd if=~/Downloads/nixos-minimal.iso of=/dev/sdX bs=4M status=progress
```

> ⚠️ Double-check the disk number. `dd` will happily erase the wrong drive.

---

## Phase 2: Install NixOS on the Mac Mini

### Boot from USB

1. Shut down the Mac Mini
2. Plug in USB drive + keyboard + wired ethernet
3. Power on, **hold Option (⌥)** immediately
4. Select the USB drive (shows as "EFI Boot")

### Verify network

```sh
ping -c3 google.com
```

### Partition the SSD

```sh
# Identify the internal SSD (likely /dev/sda, verify size = ~250GB)
lsblk

# Wipe and create GPT partition table
parted /dev/sda -- mklabel gpt

# EFI System Partition (512MB)
parted /dev/sda -- mkpart ESP fat32 1MB 512MB
parted /dev/sda -- set 1 esp on

# Root partition (rest of disk)
parted /dev/sda -- mkpart root ext4 512MB 100%

# Format
mkfs.fat -F 32 -n BOOT /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

# Mount
mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
```

### Generate hardware config

```sh
nixos-generate-config --root /mnt
```

### Write the bootstrap config

```sh
cat > /mnt/etc/nixos/configuration.nix << 'EOF'
{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };

  networking = {
    hostName = "macmini";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.devops = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  environment.systemPackages = with pkgs; [ vim git curl htop ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  time.timeZone = "America/Los_Angeles";
  system.stateVersion = "24.11";
}
EOF
```

### Install

```sh
nixos-install
# Set root password when prompted
reboot
```

**Remove the USB drive during reboot.**

---

## Phase 3: Apply Fleet Config

### First boot

Log in as `devops` / `changeme`.

```sh
# Verify NixOS is running
cat /etc/os-release

# Verify Podman works
podman run --rm docker.io/library/alpine echo "🪨 rockhard"
```

### Clone and apply

```sh
cd ~
git clone https://github.com/ohmco/rockhard_nix.git
cd rockhard_nix

# Copy the REAL hardware config into the repo
cp /etc/nixos/hardware-configuration.nix hosts/macmini/hardware.nix

# !! IMPORTANT: Add your SSH public key to modules/users.nix !!
vim modules/users.nix

# Apply the fleet configuration
sudo nixos-rebuild switch --flake .#macmini

# Change your password (bootstrap used 'changeme')
passwd
```

### Commit the hardware config back

```sh
git add hosts/macmini/hardware.nix
git commit -m "feat(macmini): add real hardware config"
git push
```

---

## Day-to-Day Usage

### Enter the dev shell

```sh
cd rockhard_nix
nix develop
```

### Deploy

```sh
colmena apply --on macmini       # single host
colmena apply --on @home-lab     # all hosts with tag
colmena apply                    # entire fleet
```

### Build without deploying

```sh
colmena build --on macmini
```

### Remote commands

```sh
colmena exec --on macmini -- podman ps
colmena exec --on @home-lab -- uptime
```

### Build a Nix OCI image

```sh
nix build .#packages.x86_64-linux.example-image
podman load < result
podman run --rm -it rockhard/example
```

---

## Adding a New Machine

1. Copy the template:
   ```sh
   cp -r hosts/_template hosts/myhost
   ```

2. Install NixOS on the new machine (Phase 2 above)

3. Copy the generated hardware config:
   ```sh
   scp root@myhost:/etc/nixos/hardware-configuration.nix hosts/myhost/hardware.nix
   ```

4. Edit `hosts/myhost/default.nix` with host-specific config

5. Add the host to `parts/colmena.nix`:
   ```nix
   myhost = { name, nodes, ... }: {
     imports = [ ../hosts/myhost ];
     deployment = {
       targetHost = "myhost.local";
       targetUser = "root";
       tags = [ "home-lab" ];
     };
   };
   ```

6. Deploy:
   ```sh
   colmena apply --on myhost
   ```

---

## Stack

| Layer | Tool | Why |
|-------|------|-----|
| **OS** | NixOS | Declarative, reproducible, atomic upgrades |
| **Flake framework** | flake-parts | Modular, composable flake outputs |
| **Fleet deploy** | Colmena | Stateless, parallel, tag-based SSH deploys |
| **Containers** | Podman | Daemonless, rootless, Docker-compatible |
| **Image builds** | dockerTools | Pure Nix OCI images, no Dockerfile needed |

## License

MIT
