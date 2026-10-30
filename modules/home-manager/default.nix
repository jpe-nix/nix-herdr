{ inputs }:
{ ... }:
{
  # Use the pinned upstream module once, including when the caller's Home
  # Manager already ships it. Only this module receives its matching helpers.
  disabledModules = [ "programs/herdr.nix" ];

  imports = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
      (import (inputs.home-manager-src + "/modules/programs/herdr.nix")) {
        inherit config pkgs;
        lib = lib // {
          hm = lib.hm // {
            generators =
              (lib.hm.generators or { })
              // (import (inputs.home-manager-src + "/modules/lib/generators.nix") { inherit lib; });
          };
        };
      }
    )
    (import ./options.nix { inherit inputs; })
    ./settings.nix
    ./services.nix
    (import ./collie.nix { inherit inputs; })
    (import ./native-ui.nix { inherit inputs; })
    (import ./integrations.nix { inherit inputs; })
  ];
}
