{ inputs, ... }: {
  perSystem = { pkgs, system, ... }: {
    devShells.default = pkgs.mkShell {
      buildInputs = [
        inputs.colmena.packages.${system}.colmena
        pkgs.nixos-rebuild
      ];

      shellHook = ''
        echo ""
        echo "🪨 rockhard_nix — fleet management shell"
        echo ""
        echo "  Deploy:"
        echo "    colmena apply --on macmini       # single host"
        echo "    colmena apply --on @home-lab     # by tag"
        echo "    colmena apply                    # entire fleet"
        echo ""
        echo "  Build only (no deploy):"
        echo "    colmena build --on macmini"
        echo ""
        echo "  Remote commands:"
        echo "    colmena exec --on macmini -- podman ps"
        echo ""
      '';
    };
  };
}
