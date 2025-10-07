# Build derivation - extracts pre-built GStreamer Android binaries
{ pkgs, config, androidComposition, gstreamerSource }:

pkgs.stdenv.mkDerivation {
  pname = "gstreamer-android-jni";
  version = config.gstreamerVersion;

  src = gstreamerSource;

  # Minimal build inputs
  nativeBuildInputs = with pkgs; [
    file
    findutils
  ];

  # Don't use standard build phases
  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    
    echo "📦 Extracting GStreamer ${config.gstreamerVersion}..."
    mkdir -p extracted
    tar -xf $src -C extracted --strip-components=1
    
    echo "=== Extracted directory structure ==="
    ls -la extracted/
    
    echo "=== Lib directory contents ==="
    ls -la extracted/lib/ 2>/dev/null || echo "No lib directory"
    
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    
    echo "📦 Packaging artifacts for ${config.targetAbi}..."
    mkdir -p $out/artifacts
    
    cd extracted
    
    # The universal tarball contains libs in lib/ directory
    # These are static archives (.a files), not shared libraries!
    
    echo "=== Checking for shared libraries (.so) ==="
    SO_COUNT=$(find lib -name "*.so" -type f 2>/dev/null | wc -l)
    echo "Found $SO_COUNT .so files in lib/"
    
    if [ "$SO_COUNT" -gt 0 ]; then
      echo "✓ Copying shared libraries from lib/"
      find lib -name "*.so" -type f -exec cp -v {} $out/artifacts/ \;
    else
      echo "⚠ No .so files found - this tarball contains static libraries only!"
      echo "Checking lib/gstreamer-1.0/ for plugins..."
      find lib/gstreamer-1.0 -name "*.so" -type f -exec cp -v {} $out/artifacts/ \; 2>/dev/null || true
    fi
    
    # Check if gstreamer-1.0 directory has shared libraries
    if [ -d "lib/gstreamer-1.0" ]; then
      echo "=== Checking gstreamer-1.0/ directory ==="
      ls -la lib/gstreamer-1.0/ | head -20
    fi
    
    # Copy libc++_shared.so from NDK
    echo ""
    echo "🔍 Searching for libc++_shared.so in NDK..."
    
    ANDROID_SDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk"
    
    # Try to find NDK
    NDK_DIR=""
    if [ -d "$ANDROID_SDK_ROOT/ndk-bundle" ]; then
      NDK_DIR="$ANDROID_SDK_ROOT/ndk-bundle"
    else
      # Find NDK 25.x directory
      for dir in "$ANDROID_SDK_ROOT/ndk"/*; do
        if [ -d "$dir" ] && [[ "$dir" == *"25."* ]]; then
          NDK_DIR="$dir"
          break
        fi
      done
    fi
    
    if [ -n "$NDK_DIR" ] && [ -d "$NDK_DIR" ]; then
      echo "✓ Using NDK: $NDK_DIR"
      
      # Find libc++_shared.so - use simpler find without complex expressions
      LIBCPP=""
      
      # Try specific path for arm64-v8a
      if [ "${config.targetAbi}" = "arm64-v8a" ]; then
        # Look in aarch64-linux-android directory
        SEARCH_PATH="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android"
        if [ -f "$SEARCH_PATH/libc++_shared.so" ]; then
          LIBCPP="$SEARCH_PATH/libc++_shared.so"
        fi
      fi
      
      # Fallback: search for any libc++_shared.so
      if [ -z "$LIBCPP" ]; then
        LIBCPP=$(find "$NDK_DIR" -name "libc++_shared.so" -type f 2>/dev/null | grep -i "aarch64\|arm64" | head -1)
      fi
      
      # Last resort: just find any libc++_shared.so
      if [ -z "$LIBCPP" ]; then
        LIBCPP=$(find "$NDK_DIR" -name "libc++_shared.so" -type f 2>/dev/null | head -1)
      fi
      
      if [ -n "$LIBCPP" ] && [ -f "$LIBCPP" ]; then
        cp -v "$LIBCPP" $out/artifacts/
        echo "✓ Copied libc++_shared.so from NDK"
      else
        echo "⚠ libc++_shared.so not found in NDK"
        echo "Searched in: $NDK_DIR"
      fi
    else
      echo "⚠ NDK not found at expected locations"
    fi
    
    # Verify we have libraries
    cd $out/artifacts
    FINAL_SO_COUNT=$(ls -1 *.so 2>/dev/null | wc -l)
    
    if [ "$FINAL_SO_COUNT" -eq 0 ]; then
      echo ""
      echo "❌ ERROR: No .so files were copied!"
      echo ""
      echo "=== Debug Info ==="
      echo "This GStreamer package appears to contain static libraries (.a) only."
      echo ""
      echo "Static libraries found:"
      cd ../extracted
      ls lib/*.a 2>/dev/null | head -10
      echo ""
      echo "You may need a different GStreamer package that includes shared libraries."
      echo "Or you may need to build from the Android source package instead of the universal package."
      exit 1
    fi
    
    echo ""
    echo "✅ Successfully copied $FINAL_SO_COUNT library file(s)"
    echo ""
    
    # Generate checksums
    cd $out/artifacts
    sha256sum *.so > checksums.txt
    
    # Show what we got
    echo "=== Libraries ==="
    ls -lh *.so
    
    # Create README
    cat > README.md << 'EOF'
# GStreamer Android ${config.gstreamerVersion}

Pre-built GStreamer libraries for Android ${config.targetAbi}.

## Build Information

- **GStreamer Version:** ${config.gstreamerVersion}
- **Target ABI:** ${config.targetAbi}
- **Android Platform:** ${config.androidPlatform}
- **NDK Version:** r25c (25.2.9519653)

## Installation

Copy these libraries to your Android project:

```bash
# Copy to your project
cp *.so /path/to/your/app/src/main/jniLibs/${config.targetAbi}/
Checksums
See checksums.txt for SHA256 hashes of all libraries.

EOF

text

# Substitute config values in README
sed -i "s/\''${config.gstreamerVersion}/${config.gstreamerVersion}/g" README.md
sed -i "s/\''${config.targetAbi}/${config.targetAbi}/g" README.md
sed -i "s/\''${config.androidPlatform}/${config.androidPlatform}/g" README.md

echo ""
echo "=== ✅ Build Complete ==="
echo "Artifacts: $out/artifacts"
echo "Total libraries: $FINAL_SO_COUNT"
echo ""

runHook postInstall
'';

#Passthru for debugging
passthru = {
inherit (config) gstreamerVersion targetAbi androidPlatform;
ndkVersion = "r25c";
};

#Metadata
meta = with pkgs.lib; {
description = "GStreamer Android pre-built libraries (${config.targetAbi})";
homepage = "https://gstreamer.freedesktop.org/";
license = pkgs.lib.licenses.lgpl2Plus;
platforms = pkgs.lib.platforms.linux;
};
}
