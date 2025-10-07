{ pkgs, android-nixpkgs, system }:

# Custom Android SDK/NDK configuration
android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
  # Command-line tools
  cmdline-tools-latest

  # Build tools
  build-tools-34-0-0
  build-tools-30-0-3  # Backup

  # Platform tools (adb, fastboot)
  platform-tools

  # Android platforms
  platforms-android-34
  platforms-android-33
  platforms-android-21  # Minimum for your app

  # NDK r21e (matching your GitHub Actions workflow)
  ndk-21-4-7075529

  # Alternatively, use newer NDK for GStreamer 1.26.x
  # ndk-25-2-9519653  # r25c recommended for GStreamer 1.26.x
])