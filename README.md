# GStreamer Android Nix Flake

[![Build GStreamer Android](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/build.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/build.yml)
[![CI](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml)

Build GStreamer Android libraries using Nix Flakes with reproducible builds.

## Quick Start

### Using Nix Flakes

```bash
# Build GStreamer Android
nix build

# Enter development shell
nix develop

# Run info
nix run .#info

# Run build script
nix run .#build
```

### Download Pre-built Artifacts

Download the latest pre-built libraries from [Releases](https://github.com/YOUR_USERNAME/YOUR_REPO/releases).

## GitHub Actions

This repository includes automated workflows:

- **`build.yml`** - Builds GStreamer Android for all ABIs on push/PR
- **`ci.yml`** - Runs checks and validation
- **`cache-warmup.yml`** - Weekly cache refresh (optional)

### Setup Cachix (Optional)

For faster builds, setup [Cachix](https://cachix.org):

1. Create a Cachix cache: `cachix create gstreamer-android`
2. Get auth token: `cachix authtoken`
3. Add to repository secrets: `CACHIX_AUTH_TOKEN`

## Local Development

```bash
# Check flake
nix flake check

# Show flake outputs
nix flake show

# Build specific package
nix build .#gstreamer-android

# Test in dev shell
nix develop --command gst-android-info
```

## License

[Your License]