# .idx/dev.nix
{ pkgs, lib, ... }:
let
  # Import all overlays
  overlays = import ./overlays/default.nix { inherit pkgs; };

  # Apply overlays to pkgs
  extendedPkgs = pkgs.extend (
    self: super:
      builtins.foldl' (acc: overlay: acc // overlay self super) {} overlays
  );

  # Import GStreamer Daemon module
  gstreamerDaemon = import ./modules/gstreamer-daemon {
    inherit pkgs extendedPkgs;
  };

  # Import GStreamer Android module (NEW)
  gstreamerAndroid = import ./modules/gstreamer-android {
    inherit pkgs extendedPkgs;
  };

  # Import other modules (they now use gstreamerAndroid internally)
  packages = import ./modules/packages.nix {
    inherit extendedPkgs gstreamerDaemon;
  };

  environment = import ./modules/environment.nix {
    inherit lib extendedPkgs gstreamerDaemon;
  };

  previews = import ./modules/previews.nix {
    inherit extendedPkgs;
  };

  workspace = import ./modules/workspace.nix {
    inherit extendedPkgs;
  };
in
{
  imports = [
    {
      channel = "stable-25.05";
      packages = packages;
      env = environment;
    }
    previews
    workspace
  ];
}