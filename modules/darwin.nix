{ inputs }:
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  # Expose the cask's companion CLI binaries without placing the GUI `Herdr`
  # executable on PATH.
  nativeCliBins = [
    "herdr-automate"
    "herdr-acp"
    "herdr-remote-control"
  ];
  nativeCliPackage = pkgs.symlinkJoin {
    name = "herdr-gpui-cli";
    paths = map (
      name:
      pkgs.writeShellScriptBin name ''
        target="/Applications/Herdr.app/Contents/MacOS/${name}"
        if [ ! -x "$target" ]; then
          echo "${name}: $target not found (install penso/tap/herdr-gpui)" >&2
          exit 127
        fi
        exec "$target" "$@"
      ''
    ) nativeCliBins;
  };
in
{
  options.programs.herdr.nativeUI.enable = lib.mkEnableOption "the Herdr UI Homebrew cask";
  config = lib.mkIf config.programs.herdr.nativeUI.enable (
    lib.mkMerge [
      {
        homebrew = {
          enable = true;
          taps = [ "penso/tap" ];
          casks = [ "penso/tap/herdr-gpui" ];
        };
        environment.systemPackages = [ nativeCliPackage ];
      }
      # With nix-homebrew's immutable taps, the tap must come from a locked
      # source; hosts without nix-homebrew keep tapping it through brew bundle.
      (lib.optionalAttrs (options ? nix-homebrew) {
        nix-homebrew.taps."penso/homebrew-tap" = inputs.penso-tap;
      })
    ]
  );
}
