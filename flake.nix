{
  description = "Declarative Herdr TUI and companion services";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-devenv.url = "github:dryvist/nix-devenv?ref=v0";
    herdr-upstream.url = "github:kevinpita/herdr-nix";
    collie-upstream.url = "github:AltanS/collie";
    native-ui.url = "github:penso/herdr-gpui";
    nix-claude-code = {
      url = "github:dryvist/nix-claude-code?ref=v2";
      flake = false;
    };
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
      };
      perSystem = { system, pkgs, ... }: {
        packages = {
          herdr = inputs.herdr-upstream.packages.${system}.herdr-tui;
          collie = inputs.collie-upstream.packages.${system}.collie;
          default = self.packages.${system}.herdr;
        };
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.herdr}/bin/herdr";
        };
        checks = {
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
