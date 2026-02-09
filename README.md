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
│   ├── macmini/           # Mac Mini 5,1 (2011) — dual boot with macOS
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

## Phase 1: Prepare (do this on macOS BEFORE booting the installer)

### 1a. Back up your data

Time Machine or manual copy. The resize is generally safe, but always back up first.

### 1b. Shrink the macOS partition

Open **Disk Utility** (Applications → Utilities → Disk Utility):

1. Select your internal SSD in the sidebar
2. Click **Partition**
3. Resize the macOS partition down to **60–80 GB** (enough for High Sierra + essentials)
4. **Don't create a new partition** in the free space — just leave it unallocated
5. Click **Apply** and wait for the resize to finish

If Disk Utility won't resize (sometimes it's stubborn), use Terminal:

```sh
# Check current layout
diskutil list

# Resize macOS to 70GB (adjust to your preference)
# Replace disk0s2 with your actual macOS partition identifier
sudo diskutil resizeVolume disk0s2 70G
```

After this, your 250GB SSD should look roughly like:

```
┌──────────┬────────────────────┬──────────────────────────────────┬──────────┐
│ EFI      │ macOS (High Sierra)│           FREE SPACE             │ Recovery │
│ ~200MB   │     ~70GB          │           ~170GB                 │ ~650MB   │
└──────────┴────────────────────┴──────────────────────────────────┴──────────┘
```

### 1c. Download the NixOS Minimal ISO

```sh
curl -L -o ~/Downloads/nixos-minimal.iso \
  https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso
```

### 1d. Write the ISO to USB

```sh
# Find the USB disk — look for the 8GB+ one (NOT your internal SSD!)
diskutil list

# Unmount it (replace disk2 with YOUR USB disk number)
diskutil unmountDisk /dev/disk2

# Write the ISO (rdisk is faster — replace disk2!)
sudo dd if=~/Downloads/nixos-minimal.iso of=/dev/rdisk2 bs=4m status=progress
```

### 1e. Note your disk layout

Before rebooting, write down the output of:

```sh
diskutil list
```

You'll need to know which partition is the EFI System Partition (usually `disk0s1`).

---

## Phase 2: Install NixOS (dual boot)

### 2a. Boot from USB

1. Shut down the Mac Mini
2. Plug in USB drive + keyboard + **wired ethernet**
3. Power on, **hold Option (⌥)** immediately
4. Select the USB drive (shows as "EFI Boot")
5. You'll land at a NixOS console as `root`

### 2b. Verify network

```sh
# Wired ethernet should auto-configure via DHCP
ping -c3 google.com
```

### 2c. Identify your disk layout

```sh
lsblk
# or for more detail:
fdisk -l /dev/sda
```

You should see something like:

```
sda1   200M  EFI System        ← KEEP — shared with macOS
sda2    70G  Apple HFS/APFS    ← KEEP — macOS
sda3   650M  Apple boot        ← KEEP — macOS Recovery
       170G  (free space)      ← THIS is where NixOS goes
```

### 2d. Create NixOS partition in the free space

> ⚠️ **DO NOT** run `mklabel` — that would wipe the entire partition table including macOS!

```sh
# Create the NixOS root partition in the free space
# The start/end values depend on your layout — use the free space AFTER macOS
parted /dev/sda -- mkpart root ext4 71GB 100%

# Check what partition number it got (likely sda4)
lsblk

# Format the new partition
mkfs.ext4 -L nixos /dev/sda4
```

> If `parted` complains about partition alignment, that's fine — accept the default.

### 2e. Mount filesystems

```sh
# Mount NixOS root
mount /dev/sda4 /mnt

# Mount the EXISTING EFI partition (shared with macOS)
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
```

> **Important**: We're mounting the Mac's existing EFI partition at `/mnt/boot`.
> GRUB will install alongside the macOS bootloader — it won't overwrite it.

### 2f. Generate hardware config

```sh
nixos-generate-config --root /mnt
```

### 2g. Write the bootstrap config

```sh
cat > /mnt/etc/nixos/configuration.nix << 'EOF'
{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  # Dual boot — install GRUB to existing ESP alongside macOS
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;  # Mac firmware quirk
      device = "nodev";
      # Detect macOS and add it to the boot menu
      useOSProber = true;
    };
  };

  # os-prober needs this to find macOS
  boot.loader.grub.configurationLimit = 20;

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
    settings.PasswordAuthentication = true;  # temporary
  };

  environment.systemPackages = with pkgs; [ vim git curl htop os-prober ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  time.timeZone = "America/Los_Angeles";
  system.stateVersion = "24.11";
}
EOF
```

### 2h. Install!

```sh
nixos-install
# Set root password when prompted
reboot
```

**Remove the USB drive during reboot.**

### 2i. Choosing your OS at boot

After reboot, you have two options:

- **Hold Option (⌥)** at power-on → Mac's native boot picker shows macOS and NixOS
- **Don't hold anything** → GRUB menu appears with NixOS + macOS entries

To get back to macOS anytime, just hold **Option (⌥)** at boot and select "Macintosh HD".

---

## Phase 3: Apply Fleet Config

### First boot into NixOS

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

2. Install NixOS on the new machine (Phase 2 above, or full-disk for dedicated servers)

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

## Booting Between macOS and NixOS

| Action | Result |
|--------|--------|
| Normal power on | Boots into GRUB → NixOS (default) |
| Hold **⌥** at power on | Mac boot picker → choose macOS or NixOS |
| Select macOS in GRUB | Boots macOS (if os-prober detected it) |

To change the default boot OS, edit the GRUB config or use macOS's Startup Disk preference pane.

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
