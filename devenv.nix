{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [
    sdl3
    sdl3-ttf
    sdl3-image
  ];

  scripts = {
    ide.exec = "BeefIDE";
    run.exec = ''
      BUILD_DIR=build/Debug_Linux64/PFUI
      
      if [ -z "$BUILD_DIR/assets" ]; then
        cp -r assets "$BUILD_DIR"
      fi
      
      ./$BUILD_DIR/PFUI
    '';
  };
}
