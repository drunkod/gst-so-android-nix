# Main entry point - ties everything together
{ pkgs, extendedPkgs }:

let
  # Step 1: Load configuration (instant)
  config = import ./config.nix;

  # Step 2: Setup Android SDK/NDK (cached independently)
  androidComposition = import ./android-sdk.nix {
    inherit pkgs config;
  };

  # Step 3: Download GStreamer source (cached independently)
  gstreamerSource = import ./gstreamer-source.nix {
    inherit pkgs config;
  };

  # Step 4: Build (only if inputs changed)
  gstreamerAndroidBuild = import ./build.nix {
    inherit pkgs config androidComposition gstreamerSource;
  };

  # Step 5: Create helper scripts (lightweight)
  scripts = import ./scripts.nix {
    inherit pkgs config gstreamerAndroidBuild;
  };

in {
  # Export packages
  packages = [
    gstreamerAndroidBuild
    scripts.buildScript
    scripts.testScript
    scripts.deployScript
    scripts.infoScript
  ];

  # Environment variables
  env = {
    GSTREAMER_ANDROID_VERSION = config.gstreamerVersion;
    GSTREAMER_ANDROID_NDK = "r25c";
    GSTREAMER_ANDROID_ABI = config.targetAbi;
    GSTREAMER_ANDROID_ARTIFACTS = "${gstreamerAndroidBuild}/artifacts";
  };

  # Path additions
  pathAdditions = [
    "${gstreamerAndroidBuild}/artifacts"
  ];

  # Shell hook (lightweight)
  shellHook = ''
    if [ -z "$_GST_ANDROID_INIT" ]; then
      export _GST_ANDROID_INIT=1
      echo "📱 GStreamer Android ${config.gstreamerVersion} (NDK r25c, ${config.targetAbi}) ready"
      echo "   Commands: gst-android-build, gst-android-test, gst-android-deploy"
    fi
  '';

  # Export for external use
  build = gstreamerAndroidBuild;
  inherit config androidComposition gstreamerSource;
}