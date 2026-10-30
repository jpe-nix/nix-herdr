{
  description = "Declarative Herdr TUI and companion services";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-src = {
      url = "github:nix-community/home-manager/095fef2f265c3c0da4fe315efba8f8a04495ab34";
      flake = false;
    };
    nix-devenv.url = "github:dryvist/nix-devenv?ref=v0";
    collie-upstream.url = "github:AltanS/collie";
    native-ui.url = "github:penso/herdr-gpui";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nix-devenv,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [ nix-devenv.flakeModules.nix ];
      flake = {
        lib.integrations = import ./lib/integrations.nix { inherit (inputs.nixpkgs) lib; };
        homeManagerModules.default = import ./modules/home-manager { inherit inputs; };
        homeModules.default = self.homeManagerModules.default;
        nixosModules.default = import ./modules/nixos.nix { inherit inputs; };
        darwinModules.default = import ./modules/darwin.nix;
        templates.home-manager = {
          path = ./templates/home-manager;
          description = "Home Manager configuration using nix-herdr";
        };
      };
      perSystem =
        {
          system,
          pkgs,
          config,
          ...
        }:
        {
          packages = {
            herdr = pkgs.symlinkJoin {
              name = "herdr-${pkgs.herdr.version}-with-integrations";
              paths = [ pkgs.herdr ];
              inherit (pkgs.herdr) version meta;
              postBuild = ''
                mkdir -p "$out/share/herdr"
                cp -R ${pkgs.herdr.src}/src/integration/assets "$out/share/herdr/integrations"
                chmod -R u+w "$out/share/herdr/integrations"
                for hook in "$out"/share/herdr/integrations/*/*.sh; do
                  substituteInPlace "$hook" --replace-fail python3 ${pkgs.python3}/bin/python3
                  if grep -q 'mktemp ' "$hook"; then
                    substituteInPlace "$hook" \
                      --replace-fail 'mktemp ' '${pkgs.coreutils}/bin/mktemp ' \
                      --replace-fail 'cat >' '${pkgs.coreutils}/bin/cat >' \
                      --replace-fail 'rm -f ' '${pkgs.coreutils}/bin/rm -f '
                  fi
                done
              '';
            };
            collie = inputs.collie-upstream.packages.${system}.collie;
            default = self.packages.${system}.herdr;
          };
          apps.default = {
            type = "app";
            program = "${self.packages.${system}.herdr}/bin/herdr";
          };
          devShells.default = pkgs.mkShell {
            inputsFrom = [ config.pre-commit.devShell ];
          };
          checks = {
            config = import ./checks/config.nix {
              inherit inputs pkgs;
              package = self.packages.${system}.herdr;
            };
            defaults = import ./checks/defaults.nix { inherit inputs pkgs; };
            services = import ./checks/services.nix { inherit inputs pkgs; };
            integrations = import ./checks/integrations.nix {
              inherit pkgs;
              inherit (pkgs) lib;
              package = self.packages.${system}.herdr;
            };
          };
        };
    };
}
