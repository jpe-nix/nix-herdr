{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  stub =
    { lib, ... }:
    {
      options = {
        environment.systemPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
        };
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
  cliPkg = builtins.head enabled.environment.systemPackages;
in
assert disabled.environment.systemPackages == [ ];
assert !disabled.homebrew.enable;
assert enabled.homebrew.enable;
assert enabled.homebrew.taps == [ "penso/tap" ];
assert enabled.homebrew.casks == [ "penso/tap/herdr-gpui" ];
assert builtins.length enabled.environment.systemPackages == 1;
pkgs.runCommand "herdr-darwin" { } ''
  for bin in herdr-automate herdr-acp herdr-remote-control; do
    test -x "${cliPkg}/bin/$bin"
    grep -Fq "/Applications/Herdr.app/Contents/MacOS/$bin" "${cliPkg}/bin/$bin"
  done
  test ! -e "${cliPkg}/bin/Herdr"
  touch "$out"
''
