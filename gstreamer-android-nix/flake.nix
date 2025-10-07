{
  description = "Cross-compile GStreamer 1.26.6 for Android (aarch64)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, android-nixpkgs }:
    let
      system = "x86_64-linux";

      # Build platform (your development machine)
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Import the cross-compilation module
      gstreamerCross = import ./modules/gstreamer-android-cross.nix {
        inherit pkgs android-nixpkgs system;
      };

    in {
      # Build packages
      packages.${system} = {
        default = gstreamerCross.artifacts;

        # Individual components
        gstreamer-android = gstreamerCross.gstreamer;
        gstreamer-jni = gstreamerCross.jniWrapper;
        artifacts = gstreamerCross.artifacts;

        # Compatibility with your workflow
        libgstreamer_android = gstreamerCross.libgstreamer_android;
        libcpp_shared = gstreamerCross.libcpp_shared;
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        name = "gstreamer-android-cross";

        buildInputs = gstreamerCross.devInputs;

        shellHook = gstreamerCross.shellHook;
      };

      # Apps for testing
      apps.${system} = {
        build = {
          type = "app";
          program = "${gstreamerCross.buildScript}/bin/build-gstreamer-android";
        };

        package = {
          type = "app";
          program = "${gstreamerCross.packageScript}/bin/package-artifacts";
        };
      };
    };
}