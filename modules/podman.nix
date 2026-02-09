{ pkgs, ... }: {
  # ── Podman container runtime ────────────────────────────
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;           # alias docker -> podman
    dockerSocket.enable = true;    # /var/run/docker.sock compat
    defaultNetwork.settings = {
      dns_enabled = true;
    };
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # ── Container tooling ──────────────────────────────────
  environment.systemPackages = with pkgs; [
    podman-compose   # docker-compose replacement
    skopeo           # copy/inspect container images between registries
    dive             # explore image layers
    buildah          # build OCI images without a daemon
  ];

  # ── Rootless podman support ────────────────────────────
  # Enable lingering for the devops user so rootless containers
  # can run even when the user isn't logged in
  # (You may need to run: loginctl enable-linger devops)

  # Increase user namespaces for rootless containers
  boot.kernel.sysctl = {
    "user.max_user_namespaces" = 28633;
  };
}
