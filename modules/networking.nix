{ pkgs, ... }: {
  # ── SSH hardening ───────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
    # Only allow ed25519 and rsa host keys
    hostKeys = [
      { path = "/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
      { path = "/etc/ssh/ssh_host_rsa_key"; type = "rsa"; bits = 4096; }
    ];
  };

  # ── Firewall ───────────────────────────────────────────
  networking.firewall = {
    enable = true;
    # SSH is always allowed; host-specific ports in hosts/*/default.nix
    allowedTCPPorts = [ 22 ];
  };

  # ── NetworkManager ─────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── mDNS (so macmini.local works) ─────────────────────
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}
