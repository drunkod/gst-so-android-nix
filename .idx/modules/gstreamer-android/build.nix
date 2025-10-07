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
    # Check if there are ABI-specific subdirectories or if all libs are together
    
    if [ -d "lib/${config.targetAbi}" ]; then
      # Structure: lib/arm64-v8a/*.so
      echo "✓ Found lib/${config.targetAbi}/ directory"
      find "lib/${config.targetAbi}" -name "*.so" -type f -exec cp -v {} $out/artifacts/ \;
      
    elif [ -d "lib/gstreamer-1.0" ]; then
      # Structure: lib/gstreamer-1.0/*.so (and lib/*.so)
      echo "✓ Found GStreamer plugin directory"
      
      # Copy main libraries from lib/
      find lib -maxdepth 1 -name "*.so" -type f -exec cp -v {} $out/artifacts/ \;
      
      # Copy plugins from lib/gstreamer-1.0/
      find lib/gstreamer-1.0 -name "*.so" -type f -exec cp -v {} $out/artifacts/ \;
      
    else
      # Fallback: copy all .so files from lib/
      echo "⚠ Using fallback: copying all .so files from lib/"
      find lib -name "*.so" -type f -exec cp -v {} $out/artifacts/ \;
    fi
    
    # Also check for libgstreamer_android.so in other locations
    if [ -f "lib/libgstreamer_android.so" ]; then
      cp -v lib/libgstreamer_android.so $out/artifacts/
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
      NDK_DIR=$(find "$ANDROID_SDK_ROOT/ndk" -maxdepth 1 -type d -name "25.*" 2>/dev/null | head -1)
    fi
    
    if [ -n "$NDK_DIR" ]; then
      echo "✓ Using NDK: $NDK_DIR"
      
      # Find libc++_shared.so for our target ABI
      LIBCPP=$(find "$NDK_DIR" -name "libc++_shared.so" \
        KATEX_INLINE_OPEN -path "*/aarch64-linux-android/*" -o -path "*/${config.targetAbi}/*" KATEX_INLINE_CLOSE \
        -type f | head -1)
      
      if [ -n "$LIBCPP" ]; then
        cp -v "$LIBCPP" $out/artifacts/
        echo "✓ Copied libc++_shared.so from NDK"
      else
        echo "⚠ libc++_shared.so not found in NDK (continuing anyway)"
      fi
    else
      echo "⚠ NDK not found, skipping libc++_shared.so"
    fi
    
    # Verify we have libraries
    cd $out/artifacts
    SO_COUNT=$(ls -1 *.so 2>/dev/null | wc -l)
    
    if [ "$SO_COUNT" -eq 0 ]; then
      echo ""
      echo "❌ ERROR: No .so files were copied!"
      echo ""
      echo "=== Debug Info ==="
      echo "Searching for all .so files in extracted archive:"
      cd ../extracted
      find . -name "*.so" -type f | head -30
      echo ""
      echo "Directory structure:"
      find . -type d -maxdepth 3
      exit 1
    fi
    
    echo ""
    echo "✅ Successfully copied $SO_COUNT library file(s)"
    echo ""
    
    # Generate checksums
    cd $out/artifacts
    sha256sum *.so > checksums.txt
    
    # Show what we got
    echo "=== Libraries ==="
    ls -lh *.so | head -20
    
    # Create README
    cat > README.md << EOF
# GStreamer Android ${config.gstreamerVersion}

Pre-built GStreamer libraries for Android ${config.targetAbi}.

## Build Information

- **GStreamer Version:** ${config.gstreamerVersion}
- **Target ABI:** ${config.targetAbi}
- **Android Platform:** ${config.androidPlatform}
- **NDK Version:** r25c (25.2.9519653)
- **Library Count:** $SO_COUNT files

## Files

\`\`\`
$(ls -lh *.so | awk '{print $9, $5}')
\`\`\`

## Installation

Copy these libraries to your Android project:

\`\`\`bash
# Copy all libraries to your project
cp *.so /path/to/your/app/src/main/jniLibs/${config.targetAbi}/

# Or create the directory structure
mkdir -p app/src/main/jniLibs/${config.targetAbi}
cp *.so app/src/main/jniLibs/${config.targetAbi}/
\`\`\`

## Android Project Setup

Add to your \`app/build.gradle\`:

\`\`\`gradle
android {
    defaultConfig {
        ndk {
            abiFilters '${config.targetAbi}'
        }
    }
    
    sourceSets {
        main {
            jniLibs.srcDirs = ['src/main/jniLibs']
        }
    }
}
\`\`\`

## Checksums

See \`checksums.txt\` for SHA256 hashes of all libraries.

## License

GStreamer is licensed under LGPL v2+. See individual library licenses in the GStreamer documentation.

EOF
    
    echo ""
    echo "=== ✅ Build Complete ==="
    echo "Artifacts: $out/artifacts"
    echo "Total libraries: $SO_COUNT"
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
