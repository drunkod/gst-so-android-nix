{ lib, extendedPkgs, gstreamerDaemon }:

let
  # Import GStreamer Android module
  gstreamerAndroid = import ./gstreamer-android {
    pkgs = extendedPkgs;
    extendedPkgs = extendedPkgs;
  };

in
  # Merge all environment variables
  lib.mkMerge [
    gstreamerDaemon.env
    gstreamerAndroid.env
    {
      # Add any additional env vars here
    }
  ]