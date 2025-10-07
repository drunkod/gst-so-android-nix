{ pkgs ? import <nixpkgs> {
    config.allowUnfree = true;
  }
}:

let
  android-nixpkgs = import (builtins.fetchGit {
    url = "https://github.com/tadfisher/android-nixpkgs.git";
    ref = "main";
  }) { inherit pkgs; };

  gstreamerCross = import ./modules/gstreamer-android-cross.nix {
    inherit pkgs android-nixpkgs;
    system = "x86_64-linux";
  };

in pkgs.mkShell {
  name = "gstreamer-android-cross";

  buildInputs = gstreamerCross.devInputs;

  shellHook = gstreamerCross.shellHook;
}