# OCI container images built with Nix
#
# Build:  nix build .#packages.x86_64-linux.example-image
# Load:   podman load < result
#
{ inputs, ... }: {
  perSystem = { pkgs, ... }: {
    packages = {
      # Example: minimal Alpine-like container with just busybox
      example-image = pkgs.dockerTools.buildImage {
        name = "rockhard/example";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = with pkgs; [
            busybox
            cacert
          ];
          pathsToLink = [ "/bin" "/etc" ];
        };
        config = {
          Cmd = [ "/bin/sh" ];
          Env = [ "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" ];
        };
      };
    };
  };
}
