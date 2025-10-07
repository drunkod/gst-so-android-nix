{ pkgs ? import <nixpkgs> {
    config.allowUnfree = true;
    config.android_sdk.accept_license = true;
  }
}:

let
  # Environment variables (matching workflow)
  gstreamerVersion = "1.26.6";  # Updated from 1.22.5
  targetAbi = "arm64-v8a";
  androidPlatform = "android-21";

  # Step 3: Setup Android NDK (r21e)
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    ndkVersion = "21.4.7075529";  # NDK r21e
    platformVersions = [ "21" "34" ];
    buildToolsVersions = [ "30.0.3" "34.0.0" ];
    includeNDK = true;
    includeEmulator = false;
  };

  # Step 4: Download GStreamer
  gstreamerAndroidTarball = pkgs.fetchurl {
    url = "https://gstreamer.freedesktop.org/data/pkg/android/${gstreamerVersion}/gstreamer-1.0-android-universal-${gstreamerVersion}.tar.xz";
    sha256 = "1be059bc1de994ce8b21b6799706e35f735e861dd672a9c7cbe0e0a727e03d6a";
    # Get hash with: nix-prefetch-url <url>
  };

in pkgs.stdenv.mkDerivation {
  pname = "gstreamer-android-jni";
  version = gstreamerVersion;

  # Step 1: Source (your project files should be here)
  src = pkgs.fetchurl {
    url = gstreamerAndroidTarball.url;
    sha256 = gstreamerAndroidTarball.sha256;
  };

  nativeBuildInputs = with pkgs; [
    # Step 2: JDK 17
    jdk17
    which
    file
    findutils
    androidComposition.androidsdk
  ];

  # Step 4-5: Build phase (matching GitHub Actions)
  unpackPhase = ''
    echo "=== Step 4: Download GStreamer ==="
    # Already fetched by Nix, just extract
    mkdir -p gstreamer_android
    tar -xf $src -C gstreamer_android/

    echo "Extracted GStreamer ${gstreamerVersion}"
    ls -la gstreamer_android/
  '';

  configurePhase = ''
    echo "=== Step 5: Build - Setup ==="

    # Set NDK path
    export ANDROID_SDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk"
    export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk-bundle"
    export NDK_ROOT="$ANDROID_NDK_HOME"

    # Find actual NDK directory (might be versioned)
    if [ ! -d "$ANDROID_NDK_HOME" ]; then
      NDK_DIR=$(find $ANDROID_SDK_ROOT/ndk -maxdepth 1 -type d -name "*21.4*" | head -1)
      if [ -n "$NDK_DIR" ]; then
        export ANDROID_NDK_HOME="$NDK_DIR"
        export NDK_ROOT="$NDK_DIR"
      fi
    fi

    echo "NDK_PROJECT_PATH=$NDK_ROOT"
    echo "TARGET_ARCH_ABI=${targetAbi}"

    # Setup GStreamer environment
    export GSTREAMER_ROOT_ANDROID="$PWD/gstreamer_android"
    export TARGET_ARCH_ABI="${targetAbi}"

    # Copy gstreamer-android build files
    mkdir -p gstreamer
    cp -r gstreamer_android/* gstreamer/

    echo ""
    echo "=== Building GStreamer ${gstreamerVersion} for target ${targetAbi} ==="

    # Verify NDK
    if [ ! -f "$ANDROID_NDK_HOME/ndk-build" ]; then
      echo "ERROR: ndk-build not found at $ANDROID_NDK_HOME"
      find $ANDROID_SDK_ROOT -name "ndk-build" || true
      exit 1
    fi

    ls -la "$ANDROID_NDK_HOME/" || true
  '';

  buildPhase = ''
    echo "=== Step 5: Build - Compile ==="

    cd gstreamer
    export NDK_PROJECT_PATH="$PWD"

    # Run ndk-build (exactly as in GitHub Actions)
    $ANDROID_NDK_HOME/ndk-build \
      APP_ABI=${targetAbi} \
      APP_PLATFORM=${androidPlatform} \
      V=1

    echo ""
    echo "Build complete! Checking outputs..."
    ls -la libs/${targetAbi}/ || echo "No output in libs/${targetAbi}/"

    # Debug: show all built files
    find libs -name "*.so" -type f || true
  '';

  # Step 6: Copy artifacts
  installPhase = ''
    echo "=== Step 6: Copy libc++_shared.so and artifacts ==="

    mkdir -p $out/artifacts

    # Copy libc++_shared.so from NDK
    LIBCPP_PATH="$ANDROID_NDK_HOME/sources/cxx-stl/llvm-libc++/libs/${targetAbi}/libc++_shared.so"

    if [ -f "$LIBCPP_PATH" ]; then
      cp "$LIBCPP_PATH" $out/artifacts/
      echo "✓ Copied libc++_shared.so"
    else
      echo "WARNING: libc++_shared.so not found at $LIBCPP_PATH"
      echo "Searching for it..."
      find $ANDROID_NDK_HOME -name "libc++_shared.so" | head -5 || true

      # Try alternative path
      ALT_PATH=$(find $ANDROID_NDK_HOME -path "*/${targetAbi}/libc++_shared.so" -type f | head -1)
      if [ -n "$ALT_PATH" ]; then
        cp "$ALT_PATH" $out/artifacts/
        echo "✓ Copied libc++_shared.so from $ALT_PATH"
      fi
    fi

    # Copy libgstreamer_android.so
    if [ -f "libs/${targetAbi}/libgstreamer_android.so" ]; then
      cp libs/${targetAbi}/libgstreamer_android.so $out/artifacts/
      echo "✓ Copied libgstreamer_android.so"
    else
      echo "ERROR: libgstreamer_android.so not found!"
      ls -laR libs/ || true
      exit 1
    fi

    # Create checksums
    cd $out/artifacts
    sha256sum *.so > checksums.txt

    # Verify outputs
    echo ""
    echo "=== Artifacts ==="
    ls -lh $out/artifacts/
    echo ""
    file $out/artifacts/*.so
    echo ""
    cat checksums.txt
  '';

  meta = with pkgs.lib; {
    description = "GStreamer Android JNI wrapper (${targetAbi})";
    platforms = platforms.linux;
  };
}