{ lib, extendedPkgs, gstreamerAndroid }:

# Simple merge - don't use lib.mkMerge outside of NixOS modules
gstreamerAndroid.env // {
  # Fix disk space issues - use home directory for builds
  TMPDIR = "/home/user/tmp";
  XDG_CACHE_HOME = "/home/user/.cache";
}