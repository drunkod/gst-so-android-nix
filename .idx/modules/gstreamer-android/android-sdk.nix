# Android SDK/NDK setup - cached independently
{ pkgs, config }:

let
  # Accept Android licenses
  androidEnv = pkgs.androidenv.override { licenseAccepted = true; };

in androidEnv.composeAndroidPackages {
  ndkVersion = config.ndkVersion;
  platformVersions = config.platformVersions;
  buildToolsVersions = config.buildToolsVersions;
  includeNDK = true;
  includeEmulator = false;
}