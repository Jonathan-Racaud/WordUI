{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [
    sdl3
    sdl3-ttf
    sdl3-image

    bun # For the doc-website
  ];

  scripts = {
    ide.exec = "BeefIDE &";
    build.exec = "BeefBuild";
    run.exec = ''
      BUILD_DIR=build/Debug_Linux64/PFUI
      
      if [ -z "$BUILD_DIR/assets" ]; then
        cp -r assets "$BUILD_DIR"
      fi
      
      ./$BUILD_DIR/PFUI
    '';
    brun.exec = "build && run";
  };

  tasks = {
    "pfui:build".exec = "build";
    "pfui:run".exec = "run";
  };
}
