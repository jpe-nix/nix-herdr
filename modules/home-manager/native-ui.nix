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
    assertions = [
      {
        assertion = !pkgs.stdenv.hostPlatform.isDarwin;
        message = "On macOS, import nix-herdr.darwinModules.default and enable programs.herdr.nativeUI at the nix-darwin system level, outside home-manager.users.";
      }
    ];
    home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      inputs.native-ui.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
