{ lib, extendedPkgs, gstreamerAndroid }:

# Merge all environment variables
lib.mkMerge [
  gstreamerAndroid.env
  {
    # Fix disk space issues - use home directory for builds
    TMPDIR = "/home/user/tmp";
    XDG_CACHE_HOME = "/home/user/.cache";
  }
]