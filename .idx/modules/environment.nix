{ lib, extendedPkgs, gstreamerAndroid }:

# Merge all environment variables
lib.mkMerge [
  gstreamerAndroid.env
  {
    # Add any additional env vars here
  }
]