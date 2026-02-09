# Container Images

This directory holds Nix-built OCI container image definitions.

## How it works

Images are built using `pkgs.dockerTools.buildImage` — pure Nix, no Docker daemon needed.
The resulting images can be loaded into Podman:

```sh
# Build an image
nix build .#packages.x86_64-linux.example-image

# Load it into Podman
podman load < result

# Run it
podman run --rm -it rockhard/example
```

## Adding new images

1. Create a new `.nix` file in this directory
2. Add it to `parts/images.nix`
3. Build with `nix build`

## Why Nix-built images?

- **Reproducible**: Same inputs = same image, every time
- **Minimal**: Only includes what you specify (no base OS bloat)
- **No Dockerfile**: Declarative Nix expressions instead of imperative shell commands
- **Cached**: Nix store deduplication means shared dependencies aren't duplicated
