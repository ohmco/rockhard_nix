{ inputs, ... }: {
  flake = {
    # Colmena hive — the fleet definition
    colmenaHive = inputs.colmena.lib.makeHive {
      meta = {
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
        };
        specialArgs = { inherit inputs; };
      };

      # ── Shared defaults for every machine ──────────────────
      defaults = { pkgs, ... }: {
        imports = [
          ../modules/base.nix
          ../modules/podman.nix
          ../modules/networking.nix
          ../modules/users.nix
        ];
      };

      # ── Mac Mini 5,1 (2011) ────────────────────────────────
      macmini = { name, nodes, ... }: {
        imports = [ ../hosts/macmini ];

        deployment = {
          targetHost = "macmini.local"; # mDNS — or use IP
          targetUser = "root";
          tags = [ "home-lab" "docker-host" ];
        };
      };

      # ── Add more hosts below ───────────────────────────────
      # nas = { ... };
      # rpi4 = { ... };
    };

    # Also expose as a regular NixOS config for nixos-rebuild
    nixosConfigurations.macmini = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ../hosts/macmini
        ../modules/base.nix
        ../modules/podman.nix
        ../modules/networking.nix
        ../modules/users.nix
      ];
    };
  };
}
