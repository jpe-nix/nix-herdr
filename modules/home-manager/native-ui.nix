{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.programs.herdr.nativeUI.enable = lib.mkEnableOption "the Herdr UI client";
  config = lib.mkIf (config.programs.herdr.enable && config.programs.herdr.nativeUI.enable) {
    home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      inputs.native-ui.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
