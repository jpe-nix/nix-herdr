{ inputs }:
{
  config,
  lib,
  options,
  ...
}:
{
  options.programs.herdr.nativeUI.enable =
    lib.mkEnableOption "the Sheprd desktop client (formerly Herdr UI) from its official Homebrew cask";
  config = lib.mkIf config.programs.herdr.nativeUI.enable (
    lib.mkMerge [
      {
        # The cask installs /Applications/Sheprd.app and links the `sheprd` command.
        homebrew = {
          enable = true;
          taps = [ "sheprd-labs/tap" ];
          casks = [ "sheprd-labs/tap/sheprd" ];
        };
      }
      # With nix-homebrew's immutable taps, the tap must come from a locked
      # source; hosts without nix-homebrew keep tapping it through brew bundle.
      (lib.optionalAttrs (options ? nix-homebrew) {
        nix-homebrew.taps."sheprd-labs/homebrew-tap" = inputs.sheprd-tap;
      })
    ]
  );
}
