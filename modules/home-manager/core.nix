{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.herdr.core;
in
{
  options.programs.herdr.core = {
    enable = lib.mkEnableOption "herdr-core (`hc`), which Herdr clients such as the mobile app start over SSH";
    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.herdr-core;
      defaultText = lib.literalExpression "nix-herdr.packages.\${system}.herdr-core";
      description = "The herdr-core package. It must provide `herdr-core` on the SSH login's `PATH`.";
    };
  };
  config = lib.mkIf (config.programs.herdr.enable && cfg.enable) {
    home.packages = [ cfg.package ];
  };
}
