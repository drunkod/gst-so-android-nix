{ extendedPkgs, gstreamerDaemon }:

let
  # Import GStreamer Android module
  gstreamerAndroid = import ./gstreamer-android {
    pkgs = extendedPkgs;
    extendedPkgs = extendedPkgs;
  };

in
  # Combine all packages
  gstreamerDaemon.packages ++
  gstreamerAndroid.packages ++
  (with extendedPkgs; [
    # Add any additional packages here
  ])