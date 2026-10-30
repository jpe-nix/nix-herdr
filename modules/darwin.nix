{ config, lib, ... }:
{
  options.programs.herdr.nativeUI.enable = lib.mkEnableOption "the Herdr UI Homebrew cask";
  config = lib.mkIf config.programs.herdr.nativeUI.enable {
    homebrew = {
      enable = true;
      taps = [ "penso/tap" ];
      casks = [ "penso/tap/herdr-gpui" ];
    };
  };
}
