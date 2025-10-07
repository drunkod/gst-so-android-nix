# Build derivation - only runs if inputs change
{ pkgs, config, androidComposition, gstreamerSource }:

pkgs.stdenv.mkDerivation {
  pname = "gstreamer-android-jni";
  version = config.gstreamerVersion;

  src = gstreamerSource;

  # Minimal build inputs to speed up evaluation
  nativeBuildInputs = with pkgs; [
    jdk17
    which
    file
    findutils
  ] ++ [ androidComposition.androidsdk ];

  # Quick unpack
  unpackPhase = ''
    echo "📦 Extracting GStreamer ${config.gstreamerVersion}..."
    mkdir -p gstreamer_android
    tar -xf $src -C gstreamer_android/
  '';

  # Configure Android environment
  configurePhase = ''
    echo "🔧 Configuring Android NDK..."

    export ANDROID_SDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk"
    export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk-bundle"
    export NDK_ROOT="$ANDROID_NDK_HOME"

    # Find NDK r25c directory
    if [ ! -d "$ANDROID_NDK_HOME" ]; then
      NDK_DIR=$(find $ANDROID_SDK_ROOT/ndk -maxdepth 1 -type d -name "25.2.*" | head -1)
      if [ -n "$NDK_DIR" ]; then
        export ANDROID_NDK_HOME="$NDK_DIR"
        export NDK_ROOT="$NDK_DIR"
      fi
    fi

    echo "✓ Using NDK: $ANDROID_NDK_HOME"

    export GSTREAMER_ROOT_ANDROID="$PWD/gstreamer_android"
    export TARGET_ARCH_ABI="${config.targetAbi}"

    mkdir -p gstreamer
    cp -r gstreamer_android/* gstreamer/

    # Verify ndk-build exists
    if [ ! -f "$ANDROID_NDK_HOME/ndk-build" ]; then
      echo "❌ ERROR: ndk-build not found at $ANDROID_NDK_HOME"
      exit 1
    fi
  '';

  # Build phase
  buildPhase = ''
    echo "🔨 Building for ${config.targetAbi}..."

    cd gstreamer
    export NDK_PROJECT_PATH="$PWD"

    $ANDROID_NDK_HOME/ndk-build \
      APP_ABI=${config.targetAbi} \
      APP_PLATFORM=${config.androidPlatform} \
      V=1
  '';

  # Install artifacts
  installPhase = ''
    echo "📦 Packaging artifacts..."
    mkdir -p $out/artifacts

    # Copy libc++_shared.so (NDK r25c location)
    LIBCPP_PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

    if [ -f "$LIBCPP_PATH" ]; then
      cp "$LIBCPP_PATH" $out/artifacts/
      echo "✓ libc++_shared.so"
    else
      # Fallback search
      ALT_PATH=$(find $ANDROID_NDK_HOME -name "libc++_shared.so" -path "*/${config.targetAbi}*" -o -path "*/aarch64-linux-android/*" | head -1)
      if [ -n "$ALT_PATH" ]; then
        cp "$ALT_PATH" $out/artifacts/
        echo "✓ libc++_shared.so (from $ALT_PATH)"
      fi
    fi

    # Copy libgstreamer_android.so
    if [ -f "libs/${config.targetAbi}/libgstreamer_android.so" ]; then
      cp libs/${config.targetAbi}/libgstreamer_android.so $out/artifacts/
      echo "✓ libgstreamer_android.so"
    else
      echo "❌ ERROR: libgstreamer_android.so not found"
      exit 1
    fi

    # Create checksums
    cd $out/artifacts
    sha256sum *.so > checksums.txt 2>/dev/null || true

    # Create README
    cat > README.md << EOF
# GStreamer Android ${config.gstreamerVersion}

Built with NDK r25c for ${config.targetAbi}

## Files:
- libgstreamer_android.so - GStreamer JNI wrapper
- libc++_shared.so - C++ standard library

## Build Info:
- GStreamer: ${config.gstreamerVersion}
- NDK: r25c (25.2.9519653)
- Target ABI: ${config.targetAbi}
- Platform: ${config.androidPlatform}

## Usage:
Copy to: app/src/main/jniLibs/${config.targetAbi}/
EOF

    echo "✅ Build complete!"
    ls -lh
  '';

  # Passthru for debugging
  passthru = {
    inherit (config) gstreamerVersion targetAbi androidPlatform;
    ndkVersion = "r25c";
  };

  # Metadata
  meta = with pkgs.lib; {
    description = "GStreamer Android JNI wrapper (${config.targetAbi}) built with NDK r25c";
    platforms = platforms.linux;
  };
}