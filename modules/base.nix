{ pkgs, ... }: {
  # ── Nix settings ─────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      # Trust the deploy user
      trusted-users = [ "root" "devops" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # ── Locale & time ───────────────────────────────────────
  time.timeZone = "America/Los_Angeles"; # adjust
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Essential packages ──────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    btop
    tmux
    jq
    fd
    ripgrep
    tree
    unzip
    ncdu
  ];

  # ── System ──────────────────────────────────────────────
  # Enable automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false; # manual reboots only
  };

  # Journal — don't let logs eat the disk
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month
  '';
}
