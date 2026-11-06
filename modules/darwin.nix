{ inputs }:
{
  config,
  lib,
  options,
  ...
}:
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
      }
      # With nix-homebrew's immutable taps, the tap must come from a locked
      # source; hosts without nix-homebrew keep tapping it through brew bundle.
      (lib.optionalAttrs (options ? nix-homebrew) {
        nix-homebrew.taps."penso/homebrew-tap" = inputs.penso-tap;
      })
    ]
  );
}
