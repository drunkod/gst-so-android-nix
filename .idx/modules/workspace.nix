# .idx/modules/workspace.nix
{ extendedPkgs }:

{
  idx.workspace = {
    onCreate = {
      # Create directories for temp and cache
      setup-dirs = ''
        mkdir -p ~/tmp
        mkdir -p ~/.cache/nix
      '';
      
      welcome = ''
        echo "╔═══════════════════════════════════════════════════╗"
        echo "║  🎨 Slint Android Development Environment        ║"
        echo "╚═══════════════════════════════════════════════════╝"
        echo ""
        echo "Commands:"
        echo "  slint-android-run        Run on emulator/device"
        echo "  slint-android-build      Build APK"
        echo "  slint-android-emulator   Start emulator"
        echo "  slint-android-info       Show help"
        echo ""
      '';
    };

    onStart = {
      info = "slint-android-info";
    };
  };
}