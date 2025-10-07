# Helper scripts - lightweight, no heavy dependencies
{ pkgs, config, gstreamerAndroidBuild }:

{
  buildScript = pkgs.writeShellScriptBin "gst-android-build" ''
    echo "🔨 Building GStreamer Android ${config.gstreamerVersion}..."
    nix-build -A gstreamerAndroid
    echo "✅ Artifacts: ./result/artifacts/"
    ls -lh ./result/artifacts/
  '';

  testScript = pkgs.writeShellScriptBin "gst-android-test" ''
    echo "🧪 Testing GStreamer Android ${config.gstreamerVersion} (NDK r25c)..."
    echo ""

    if [ ! -d "${gstreamerAndroidBuild}/artifacts" ]; then
      echo "❌ Artifacts not found. Run: gst-android-build"
      exit 1
    fi

    echo "📦 Artifacts:"
    ls -lh ${gstreamerAndroidBuild}/artifacts/
    echo ""

    echo "🔍 File types:"
    file ${gstreamerAndroidBuild}/artifacts/*.so
    echo ""

    echo "✅ Architecture verification:"
    for so in ${gstreamerAndroidBuild}/artifacts/*.so; do
      if file "$so" | grep -q "ARM aarch64"; then
        echo "  ✓ $(basename "$so") - ARM aarch64 ✓"
      else
        echo "  ✗ $(basename "$so") - Wrong architecture!"
      fi
    done
    echo ""

    if [ -f "${gstreamerAndroidBuild}/artifacts/README.md" ]; then
      echo "📝 Build info:"
      cat ${gstreamerAndroidBuild}/artifacts/README.md
    fi
  '';

  deployScript = pkgs.writeShellScriptBin "gst-android-deploy" ''
    TARGET="''${1:-./jniLibs/${config.targetAbi}}"
    echo "📱 Deploying GStreamer ${config.gstreamerVersion} (NDK r25c) to: $TARGET"
    mkdir -p "$TARGET"
    cp -v ${gstreamerAndroidBuild}/artifacts/*.so "$TARGET/"
    echo "✅ Done!"
    ls -lh "$TARGET"
  '';

  infoScript = pkgs.writeShellScriptBin "gst-android-info" ''
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║  📱 GStreamer Android ${config.gstreamerVersion}          ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    echo "Version:   ${config.gstreamerVersion}"
    echo "NDK:       r25c (25.2.9519653)"
    echo "ABI:       ${config.targetAbi}"
    echo "Platform:  ${config.androidPlatform}"
    echo ""
    echo "Artifacts: ${gstreamerAndroidBuild}/artifacts/"
    echo ""
    echo "Commands:"
    echo "  gst-android-build   - Build artifacts"
    echo "  gst-android-test    - Test build"
    echo "  gst-android-deploy  - Deploy to project"
    echo "  gst-android-info    - Show this info"
    echo ""
  '';
}