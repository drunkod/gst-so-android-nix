# flake.nix
{
  description = "GStreamer Android Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        lib = pkgs.lib;

        # Import all overlays
        overlays = import ./.idx/overlays/default.nix { inherit pkgs; };

        # Apply overlays to pkgs
        extendedPkgs = pkgs.extend (
          self: super:
            builtins.foldl' (acc: overlay: acc // overlay self super) {} overlays
        );

        # Import GStreamer Android module
        gstreamerAndroid = import ./.idx/modules/gstreamer-android {
          inherit pkgs extendedPkgs;
        };

        # Import packages module
        packages = import ./.idx/modules/packages.nix {
          inherit extendedPkgs gstreamerAndroid;
        };

        # Import environment module
        environment = import ./.idx/modules/environment.nix {
          inherit lib extendedPkgs gstreamerAndroid;
        };

        # Convert environment to shell variables
        envVars = lib.mapAttrs (name: value: 
          if builtins.isString value then value
          else if builtins.isBool value then (if value then "1" else "0")
          else toString value
        ) environment;

      in {
        # Default package is the GStreamer Android build
        packages = {
          default = gstreamerAndroid.build;
          gstreamer-android = gstreamerAndroid.build;
          
          # Expose individual scripts
          build-script = pkgs.writeShellScriptBin "gst-android-build" ''
            echo "🔨 Building GStreamer Android..."
            nix build .#gstreamer-android
            echo "✅ Artifacts: ./result/artifacts/"
            ls -lh ./result/artifacts/
          '';
          
          test-script = pkgs.writeShellScriptBin "gst-android-test" ''
            echo "🧪 Testing GStreamer Android..."
            if [ -d "./result/artifacts" ]; then
              ls -lh ./result/artifacts/
              file ./result/artifacts/*.so
            else
              echo "❌ Build first with: nix build"
            fi
          '';
        };

        # Development shell
        devShells = {
          default = pkgs.mkShell {
            # Include all packages
            buildInputs = packages ++ (with pkgs; [
              # Additional dev tools
              git
              curl
              jq
              ripgrep
              fd
            ]);

            # Set environment variables
            inherit (envVars) 
              GSTREAMER_ANDROID_VERSION
              GSTREAMER_ANDROID_NDK
              GSTREAMER_ANDROID_ABI
              GSTREAMER_ANDROID_ARTIFACTS;

            # Shell hook
            shellHook = ''
              echo "╔═══════════════════════════════════════════════════╗"
              echo "║  📱 GStreamer Android Development Environment     ║"
              echo "╚═══════════════════════════════════════════════════╝"
              echo ""
              echo "GStreamer: ${gstreamerAndroid.config.gstreamerVersion}"
              echo "NDK:       r25c"
              echo "ABI:       ${gstreamerAndroid.config.targetAbi}"
              echo "Platform:  ${gstreamerAndroid.config.androidPlatform}"
              echo ""
              echo "Commands:"
              echo "  nix build              - Build GStreamer Android"
              echo "  nix develop            - Enter dev shell"
              echo "  nix flake show         - Show all outputs"
              echo "  nix flake check        - Run checks"
              echo ""
              echo "Scripts:"
              echo "  gst-android-build      - Build artifacts"
              echo "  gst-android-test       - Test build"
              echo "  gst-android-deploy     - Deploy to project"
              echo "  gst-android-info       - Show info"
              echo ""
              
              ${gstreamerAndroid.shellHook or ""}
            '';
          };

          # Minimal shell for quick testing
          minimal = pkgs.mkShell {
            buildInputs = with pkgs; [
              jdk17
              git
            ];
            
            shellHook = ''
              echo "📱 Minimal GStreamer Android Shell"
              echo "Run 'nix develop' for full environment"
            '';
          };
        };

        # Apps (runnable with `nix run`)
        apps = {
          # Default app shows info
          default = {
            type = "app";
            program = "${self.packages.${system}.test-script}/bin/gst-android-test";
          };

          build = {
            type = "app";
            program = "${self.packages.${system}.build-script}/bin/gst-android-build";
          };

          info = {
            type = "app";
            program = let
              infoScript = pkgs.writeShellScriptBin "gst-android-info" ''
                echo ""
                echo "╔════════════════════════════════════════════╗"
                echo "║  📱 GStreamer Android ${gstreamerAndroid.config.gstreamerVersion}          ║"
                echo "╚════════════════════════════════════════════╝"
                echo ""
                echo "Version:   ${gstreamerAndroid.config.gstreamerVersion}"
                echo "NDK:       r25c (25.2.9519653)"
                echo "ABI:       ${gstreamerAndroid.config.targetAbi}"
                echo "Platform:  ${gstreamerAndroid.config.androidPlatform}"
                echo ""
                echo "Commands:"
                echo "  nix build              - Build artifacts"
                echo "  nix run .#build        - Run build script"
                echo "  nix run .#info         - Show this info"
                echo "  nix develop            - Enter dev shell"
                echo ""
              '';
            in "${infoScript}/bin/gst-android-info";
          };
        };

        # Checks (run with `nix flake check`)
        checks = {
          # Check if config loads
          config-check = pkgs.runCommand "config-check" {} ''
            echo "Checking config..."
            echo "GStreamer: ${gstreamerAndroid.config.gstreamerVersion}"
            echo "NDK: ${gstreamerAndroid.config.ndkVersion}"
            echo "ABI: ${gstreamerAndroid.config.targetAbi}"
            touch $out
          '';

          # Check if scripts build
          scripts-check = pkgs.runCommand "scripts-check" {} ''
            echo "Checking scripts..."
            ${self.packages.${system}.build-script}/bin/gst-android-build --help || true
            ${self.packages.${system}.test-script}/bin/gst-android-test --help || true
            touch $out
          '';
        };

        # Overlay for using in other flakes
        overlays.default = final: prev: {
          gstreamer-android = gstreamerAndroid.build;
        };
      }
    );
}