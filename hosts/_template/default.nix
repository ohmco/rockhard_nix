# Template for adding new hosts
#
# 1. Copy this directory:  cp -r hosts/_template hosts/myhost
# 2. Edit default.nix with host-specific config
# 3. Generate hardware.nix on the target machine:
#      nixos-generate-config --root /mnt
#      cp /mnt/etc/nixos/hardware-configuration.nix hosts/myhost/hardware.nix
# 4. Add the host to parts/colmena.nix
# 5. Deploy:  colmena apply --on myhost

{ config, pkgs, ... }: {
  imports = [ ./hardware.nix ];

  networking.hostName = "changeme";

  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
    };
    efi.canTouchEfiVariables = true;
  };

  networking.firewall.allowedTCPPorts = [
    # Add ports for your services
  ];

  system.stateVersion = "24.11";
}
