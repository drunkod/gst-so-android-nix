{ pkgs, android-nixpkgs, system }:

let
  # Android NDK setup (matching your workflow's NDK r21e)
  androidSdk = android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
    cmdline-tools-latest
    build-tools-34-0-0
    platform-tools
    platforms-android-34
    platforms-android-21  # Minimum API level from your workflow
    ndk-21-4-7075529      # NDK r21e (closest match)
  ]);

  # Cross-compilation package set for Android aarch64
  pkgsAndroid = import pkgs.path {
    crossSystem = {
      config = "aarch64-unknown-linux-android";
      # Alternatively use the predefined one:
      # pkgs.pkgsCross.aarch64-android-prebuilt
    };
    overlays = [
      (self: super: {
        # Override Android SDK
        androidndk = androidSdk;
      })
    ];
  };

  # GStreamer version
  gstreamerVersion = "1.26.6";

  # Download official GStreamer Android source/binaries for reference
  gstreamerAndroidBinaries = pkgs.fetchurl {
    url = "https://gstreamer.freedesktop.org/data/pkg/android/${gstreamerVersion}/gstreamer-1.0-android-universal-${gstreamerVersion}.tar.xz";
    sha256 = "1be059bc1de994ce8b21b6799706e35f735e861dd672a9c7cbe0e0a727e03d6a";
    # Get with: nix-prefetch-url <url>
  };

  # Extract GStreamer Android binaries
  gstreamerExtracted = pkgs.stdenv.mkDerivation {
    name = "gstreamer-android-extracted-${gstreamerVersion}";
    src = gstreamerAndroidBinaries;

    unpackPhase = ''
      tar xf $src
    '';

    installPhase = ''
      mkdir -p $out
      # Copy arm64-v8a (aarch64) architecture
      cp -r arm64/* $out/
    '';
  };

  # JNI wrapper library (mimicking your GitHub Actions build)
  jniWrapper = pkgs.stdenv.mkDerivation {
    pname = "libgstreamer_android";
    version = gstreamerVersion;

    # Source files for JNI wrapper
    src = pkgs.writeTextDir "gstreamer_android.c" ''
      #include <jni.h>
      #include <android/log.h>
      #include <gst/gst.h>

      #define LOG_TAG "GStreamer-Android"
      #define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
      #define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

      static JavaVM *java_vm;
      static pthread_key_t current_jni_env;
      static pthread_once_t current_jni_env_once = PTHREAD_ONCE_INIT;

      /* Initialize GStreamer and register plugins */
      void gst_android_init(void) {
          gst_init(NULL, NULL);
          LOGD("GStreamer initialized");
      }

      /* JNI entry point */
      JNIEXPORT jint JNICALL
      JNI_OnLoad(JavaVM *vm, void *reserved) {
          JNIEnv *env = NULL;
          java_vm = vm;

          if ((*vm)->GetEnv(vm, (void**) &env, JNI_VERSION_1_6) != JNI_OK) {
              LOGE("Could not retrieve JNIEnv");
              return 0;
          }

          gst_android_init();

          LOGD("GStreamer JNI wrapper loaded (version ${gstreamerVersion})");
          return JNI_VERSION_1_6;
      }

      /* Native method to initialize GStreamer */
      JNIEXPORT void JNICALL
      Java_org_freedesktop_gstreamer_GStreamer_nativeInit(JNIEnv* env, jclass klass) {
          gst_android_init();
      }

      /* Get GStreamer version */
      JNIEXPORT jstring JNICALL
      Java_org_freedesktop_gstreamer_GStreamer_nativeGetVersion(JNIEnv* env, jclass klass) {
          guint major, minor, micro, nano;
          gst_version(&major, &minor, &micro, &nano);

          char version[64];
          snprintf(version, sizeof(version), "%u.%u.%u", major, minor, micro);

          return (*env)->NewStringUTF(env, version);
      }
    '';

    nativeBuildInputs = with pkgs; [
      androidSdk
      which
      file
    ];

    buildInputs = [
      gstreamerExtracted
    ];

    # Android build configuration
    makeFlags = [
      "APP_ABI=arm64-v8a"
      "APP_PLATFORM=android-21"
      "NDK_PROJECT_PATH=${placeholder "out"}"
    ];

    preBuild = ''
      export ANDROID_HOME="${androidSdk}/share/android-sdk"
      export ANDROID_NDK_HOME="${androidSdk}/share/android-sdk/ndk-bundle"
      export NDK_ROOT="$ANDROID_NDK_HOME"
      export GSTREAMER_ROOT_ANDROID="${gstreamerExtracted}"

      # Create Android.mk
      mkdir -p jni
      cat > jni/Android.mk << 'EOF'
      LOCAL_PATH := $(call my-dir)

      include $(CLEAR_VARS)

      LOCAL_MODULE := gstreamer_android
      LOCAL_SRC_FILES := ../gstreamer_android.c

      LOCAL_SHARED_LIBRARIES := gstreamer_android
      LOCAL_LDLIBS := -llog -landroid

      # Include GStreamer
      GSTREAMER_ROOT        := $(GSTREAMER_ROOT_ANDROID)
      GSTREAMER_NDK_BUILD_PATH  := $(GSTREAMER_ROOT)/share/gst-android/ndk-build/
      GSTREAMER_PLUGINS         := coreelements playback androidmedia
      GSTREAMER_EXTRA_DEPS      := gstreamer-video-1.0 gstreamer-audio-1.0

      include $(GSTREAMER_NDK_BUILD_PATH)/gstreamer-1.0.mk

      include $(BUILD_SHARED_LIBRARY)
      EOF

      # Create Application.mk
      cat > jni/Application.mk << 'EOF'
      APP_ABI := arm64-v8a
      APP_PLATFORM := android-21
      APP_STL := c++_shared
      EOF
    '';

    buildPhase = ''
      # Use ndk-build if available, otherwise compile directly
      if [ -f "$ANDROID_NDK_HOME/ndk-build" ]; then
        $ANDROID_NDK_HOME/ndk-build APP_ABI=arm64-v8a APP_PLATFORM=android-21
      else
        # Fallback: direct compilation
        mkdir -p libs/arm64-v8a

        $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang \
          -shared \
          -o libs/arm64-v8a/libgstreamer_android.so \
          gstreamer_android.c \
          -I${gstreamerExtracted}/include/gstreamer-1.0 \
          -I${gstreamerExtracted}/include/glib-2.0 \
          -I${gstreamerExtracted}/lib/glib-2.0/include \
          -L${gstreamerExtracted}/lib \
          -lgstreamer-1.0 \
          -lgobject-2.0 \
          -lglib-2.0 \
          -llog \
          -landroid
      fi
    '';

    installPhase = ''
      mkdir -p $out/lib
      cp libs/arm64-v8a/libgstreamer_android.so $out/lib/

      # Also copy libc++_shared.so (matching your workflow)
      if [ -f "$ANDROID_NDK_HOME/sources/cxx-stl/llvm-libc++/libs/arm64-v8a/libc++_shared.so" ]; then
        cp "$ANDROID_NDK_HOME/sources/cxx-stl/llvm-libc++/libs/arm64-v8a/libc++_shared.so" $out/lib/
      fi

      # Verify
      ls -lh $out/lib/
      file $out/lib/*.so
    '';

    meta = {
      description = "GStreamer Android JNI wrapper library";
      platforms = [ "x86_64-linux" ];
    };
  };

  # Package artifacts in GitHub Actions style
  artifacts = pkgs.stdenv.mkDerivation {
    name = "gstreamer-android-artifacts-${gstreamerVersion}";

    buildInputs = [ jniWrapper ];

    unpackPhase = "true";

    installPhase = ''
      mkdir -p $out/artifacts

      # Copy .so files (matching your workflow output)
      cp ${jniWrapper}/lib/libgstreamer_android.so $out/artifacts/

      if [ -f "${jniWrapper}/lib/libc++_shared.so" ]; then
        cp ${jniWrapper}/lib/libc++_shared.so $out/artifacts/
      fi

      # Create checksums
      cd $out/artifacts
      sha256sum *.so > checksums.txt

      # Create release notes
      cat > README.md << EOF
      # GStreamer Android Artifacts ${gstreamerVersion}

      Built with Nix for arm64-v8a (aarch64)

      ## Files:
      - libgstreamer_android.so - GStreamer JNI wrapper
      - libc++_shared.so - C++ standard library

      ## Build Info:
      - GStreamer version: ${gstreamerVersion}
      - Target ABI: arm64-v8a
      - Android API level: 21
      - NDK version: r21e

      ## Usage:
      Copy these .so files to your Android app's jniLibs/arm64-v8a/ directory.
      EOF

      ls -lh
      cat README.md
    '';

    passthru = {
      libgstreamer_android = "${jniWrapper}/lib/libgstreamer_android.so";
      libcpp_shared = "${jniWrapper}/lib/libc++_shared.so";
    };
  };

  # Build script
  buildScript = pkgs.writeShellScriptBin "build-gstreamer-android" ''
    #!/usr/bin/env bash
    set -euo pipefail

    echo "╔════════════════════════════════════════════════════╗"
    echo "║  Building GStreamer ${gstreamerVersion} for Android       ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""

    echo "📦 Building JNI wrapper..."
    nix build .#gstreamer-jni

    echo ""
    echo "📦 Packaging artifacts..."
    nix build .#artifacts

    echo ""
    echo "✅ Build complete!"
    echo ""
    echo "Artifacts location:"
    ls -lh result/artifacts/
  '';

  # Package script
  packageScript = pkgs.writeShellScriptBin "package-artifacts" ''
    #!/usr/bin/env bash
    set -euo pipefail

    OUTPUT_DIR="''${1:-./android-artifacts}"

    echo "📦 Packaging GStreamer Android artifacts..."
    echo "   Output: $OUTPUT_DIR"

    mkdir -p "$OUTPUT_DIR"

    # Build and copy
    nix build .#artifacts
    cp -v result/artifacts/* "$OUTPUT_DIR/"

    echo ""
    echo "✅ Artifacts packaged to: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"
  '';

in {
  # Main outputs
  gstreamer = gstreamerExtracted;
  jniWrapper = jniWrapper;
  artifacts = artifacts;

  # Individual .so files (for compatibility)
  libgstreamer_android = "${jniWrapper}/lib/libgstreamer_android.so";
  libcpp_shared = "${jniWrapper}/lib/libc++_shared.so";

  # Development inputs
  devInputs = with pkgs; [
    androidSdk
    file
    which
    tree
    jq
  ] ++ [ buildScript packageScript ];

  # Scripts
  inherit buildScript packageScript;

  # Shell hook
  shellHook = ''
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  🎬 GStreamer ${gstreamerVersion} Android Cross-Compiler    ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "📱 Target: arm64-v8a (aarch64-linux-android)"
    echo "📦 GStreamer: ${gstreamerVersion}"
    echo "🔧 NDK: r21e"
    echo ""
    echo "🛠️  Commands:"
    echo "  build-gstreamer-android    - Build all artifacts"
    echo "  package-artifacts [dir]    - Package to directory"
    echo ""
    echo "🚀 Quick start:"
    echo "  nix build .#artifacts"
    echo "  ls result/artifacts/"
    echo ""
  '';
}