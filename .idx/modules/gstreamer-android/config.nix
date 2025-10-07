# Configuration values only - no derivations
{
  # GStreamer configuration
  gstreamerVersion = "1.26.6";
  targetAbi = "arm64-v8a";
  androidPlatform = "android-21";

  # Android SDK/NDK versions
  ndkVersion = "25.2.9519653";  # NDK r25c for GStreamer 1.26.x
  platformVersions = [ "21" "34" ];
  buildToolsVersions = [ "30.0.3" "34.0.0" ];

  # GStreamer download URL
  gstreamerUrl = version:
    "https://gstreamer.freedesktop.org/data/pkg/android/${version}/gstreamer-1.0-android-universal-${version}.tar.xz";

  # GStreamer tarball hash
  gstreamerSha256 = "sha256-mP8r4LMXqJ76nKZMYH6zBUhKaDmo7BKEsu0zxi2mm6Q=";
}