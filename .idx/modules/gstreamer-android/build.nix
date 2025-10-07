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
    find extracted/ -maxdepth 2 -type d
    
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    
    echo "📦 Packaging artifacts for ${config.targetAbi}..."
    mkdir -p $out/artifacts
    
    # Navigate to extracted directory
    cd extracted
    
    # Find the correct ABI directory
    ABI_DIR=""
    
    # Try common locations
    if [ -d "${config.targetAbi}" ]; then
      ABI_DIR="${config.targetAbi}"
      echo "✓ Found ABI directory: ${config.targetAbi}"
    elif [ -d "armv8" ] && [ "${config.targetAbi}" = "arm64-v8a" ]; then
      ABI_DIR="armv8"
      echo "✓ Found ABI directory: armv8"
    else
      echo "⚠ Searching for ${config.targetAbi} directory..."
      ABI_DIR=$(find . -maxdepth 1 -type d -name "*arm64*" -o -name "*v8a*" -o -name "armv8" | head -1)
      if [ -n "$ABI_DIR" ]; then
        echo "✓ Found directory: $ABI_DIR"
      fi
    fi
    
    if [ -z "$ABI_DIR" ]; then
      echo "❌ ERROR: Could not find ABI directory for ${config.targetAbi}"
      echo "Available directories:"
      ls -la
      exit 1
    fi
    
    # Copy GStreamer libraries
    echo "🔍 Searching for GStreamer libraries..."
    
    # Try different possible locations
    if [ -d "$ABI_DIR/lib" ]; then
      echo "✓ Found lib directory: $ABI_DIR/lib"
      
      # Copy libgstreamer_android.so if it exists
      if [ -f "$ABI_DIR/lib/libgstreamer_android.so" ]; then
        cp -v "$ABI_DIR/lib/libgstreamer_android.so" $out/artifacts/
        echo "✓ Copied libgstreamer_android.so"
      fi
      
      # Copy all .so files (in case they're needed)
      find "$ABI_DIR/lib" -name "*.so" -type f -exec cp -v {} $out/artifacts/ \; 2>/dev/null || true
      
    else
      echo "⚠ No lib directory, searching for .so files..."
      find "$ABI_DIR" -name "*.so" -type f -exec cp -v {} $out/artifacts/ \;
    fi
    
    # Copy libc++_shared.so from NDK
    echo "🔍 Searching for libc++_shared.so..."
    
    ANDROID_SDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk"
    
    # Try to find NDK
    NDK_DIR=""
    if [ -d "$ANDROID_SDK_ROOT/ndk-bundle" ]; then
      NDK_DIR="$ANDROID_SDK_ROOT/ndk-bundle"
    else
      NDK_DIR=$(find "$ANDROID_SDK_ROOT/ndk" -maxdepth 1 -type d -name "25.*" 2>/dev/null | head -1)
    fi
    
    if [ -n "$NDK_DIR" ]; then
      echo "✓ Using NDK: $NDK_DIR"
      
      # Find libc++_shared.so
      LIBCPP=$(find "$NDK_DIR" -name "libc++_shared.so" \
        KATEX_INLINE_OPEN -path "*/aarch64-linux-android/*" -o -path "*/${config.targetAbi}/*" KATEX_INLINE_CLOSE \
        | head -1)
      
      if [ -n "$LIBCPP" ]; then
        cp -v "$LIBCPP" $out/artifacts/
        echo "✓ Copied libc++_shared.so from NDK"
      else
        echo "⚠ libc++_shared.so not found in NDK (may not be needed)"
      fi
    else
      echo "⚠ NDK not found, skipping libc++_shared.so"
    fi
    
    # Verify we have at least some libraries
    cd $out/artifacts
    SO_COUNT=$(ls -1 *.so 2>/dev/null | wc -l)
    
    if [ "$SO_COUNT" -eq 0 ]; then
      echo "❌ ERROR: No .so files were copied!"
      echo "=== Debug Info ==="
      echo "Source structure:"
      cd -
      find extracted/ -name "*.so" | head -20
      exit 1
    fi
    
    echo "✅ Found $SO_COUNT library file(s)"
    
    # Generate checksums
    cd $out/artifacts
    sha256sum *.so > checksums.txt
    
    # Create README
    cat > README.md << EOF
# GStreamer Android ${config.gstreamerVersion}

Pre-built GStreamer libraries for Android.

## Build Information
- **GStreamer Version:** ${config.gstreamerVersion}
- **Target ABI:** ${config.targetAbi}
- **Android Platform:** ${config.androidPlatform}
- **NDK Version:** r25c (25.2.9519653)

## Files

\`\`\`
$(ls -lh *.so)
\`\`\`

## Installation

Copy these libraries to your Android project:

\`\`\`bash
# Copy to your Android project
cp *.so /path/to/your/app/src/main/jniLibs/${config.targetAbi}/
\`\`\`

## Checksums

See \`checksums.txt\` for SHA256 hashes of all libraries.

## Usage in Android

Add to your \`build.gradle\`:

\`\`\`gradle
android {
    sourceSets {
        main {
            jniLibs.srcDirs = ['src/main/jniLibs']
        }
    }
}
\`\`\`

EOF
    
    echo ""
    echo "=== ✅ Build Complete ==="
    echo "Artifacts location: $out/artifacts"
    echo ""
    ls -lh
    echo ""
    
    runHook postInstall
  '';

  # Passthru for debugging
  passthru = {
    inherit (config) gstreamerVersion targetAbi androidPlatform;
    ndkVersion = "r25c";
  };

  # Metadata
  meta = with pkgs.lib; {
    description = "GStreamer Android pre-built libraries (${config.targetAbi})";
    homepage = "https://gstreamer.freedesktop.org/";
    license = pkgs.lib.licenses.lgpl2Plus;
    platforms = pkgs.lib.platforms.linux;
  };
}
