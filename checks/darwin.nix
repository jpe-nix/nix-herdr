{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  stub =
    { lib, ... }:
    {
      options = {
        homebrew = {
          enable = lib.mkEnableOption "Homebrew";
          taps = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          casks = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      };
    };
  evaluate =
    extra:
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        stub
        inputs.self.darwinModules.default
        extra
      ];
    }).config;
  disabled = evaluate { };
  enabled = evaluate { programs.herdr.nativeUI.enable = true; };
in
assert !disabled.homebrew.enable;
assert enabled.homebrew.enable;
assert disabled.homebrew.taps == [ ] && disabled.homebrew.casks == [ ];
assert enabled.homebrew.taps == [ "sheprd-labs/tap" ];
assert enabled.homebrew.casks == [ "sheprd-labs/tap/sheprd" ];
pkgs.runCommand "herdr-darwin" { } "touch $out"
