{ config, pkgs, ... }: {
  imports = [ ./hardware.nix ];

  networking.hostName = "macmini";

  # ── Boot — EFI for Mac Mini 5,1 (2011) ───────────────────
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true; # Mac firmware quirk
      device = "nodev";
    };
  };

  # ── Mac Mini specific ────────────────────────────────────
  # Intel HD 3000 — uses i915 driver, well supported on Linux
  # Broadcom WiFi — if needed, uncomment:
  # networking.wireless.enable = true;
  # hardware.enableRedistributableFirmware = true;

  # Wired ethernet is recommended for a server
  # The Broadcom NIC should work out of the box

  # ── Open ports for your services ─────────────────────────
  networking.firewall.allowedTCPPorts = [
    # 8080  # web app
    # 5432  # postgres
    # 3000  # grafana
  ];

  system.stateVersion = "24.11";
}
