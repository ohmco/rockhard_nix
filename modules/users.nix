{ pkgs, ... }: {
  # ── Primary admin user ─────────────────────────────────
  users.users.devops = {
    isNormalUser = true;
    description = "Fleet operator";
    extraGroups = [
      "wheel"          # sudo
      "networkmanager" # network config
      "podman"         # container management
    ];
    openssh.authorizedKeys.keys = [
      # !! IMPORTANT: Add your SSH public key here !!
      # "ssh-ed25519 AAAA... you@machine"
    ];
  };

  # ── Sudo without password for wheel group ──────────────
  # Useful for Colmena deployments
  security.sudo.wheelNeedsPassword = false;

  # ── Root SSH keys (for Colmena deployment) ─────────────
  users.users.root.openssh.authorizedKeys.keys = [
    # !! IMPORTANT: Add your SSH public key here too !!
    # "ssh-ed25519 AAAA... you@machine"
  ];
}
