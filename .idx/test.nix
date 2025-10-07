# .idx/test.nix - Test wrapper for dev.nix
let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  
  # Import dev.nix with required arguments
  devConfig = import ./dev.nix {
    inherit pkgs lib;
  };
  
in devConfig