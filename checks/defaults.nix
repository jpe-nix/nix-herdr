{ inputs, pkgs }:
let
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = {
          username = "test";
          homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
          stateVersion = "26.05";
        };
      }
    ];
  };
  cfg = home.config.programs.herdr;
  enabled = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = {
          username = "test";
          homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
          stateVersion = "26.05";
        };
        programs.herdr = {
          enable = true;
          package = pkgs.hello;
          settings.theme.name = "test";
          machines.example.target = "example.invalid";
        };
      }
    ];
  };
  legacy = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = {
          username = "test";
          homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
          stateVersion = "26.05";
        };
        programs.herdr = {
          enable = true;
          package = pkgs.hello;
          remotes.old = "old.invalid";
        };
      }
    ];
  };
  empty = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = {
          username = "test";
          homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
          stateVersion = "26.05";
        };
        programs.herdr.enable = true;
      }
    ];
  };
  nativeUI = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = {
          username = "test";
          homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
          stateVersion = "26.05";
        };
        programs.herdr = {
          enable = true;
          nativeUI.enable = true;
        };
      }
    ];
  };
in
assert !cfg.enable;
assert !cfg.server.enable;
assert cfg.server.launchPrefix == [ ] && cfg.server.environment == { };
assert !cfg.collie.enable;
assert !cfg.nativeUI.enable;
assert !(builtins.tryEval legacy.config.programs.herdr.enable).success;
assert cfg.machines == null;
assert builtins.all (integration: !integration.enable) (builtins.attrValues cfg.integrations);
assert !enabled.config.programs.herdr.server.enable;
assert builtins.hasAttr "herdr/config.toml" enabled.config.xdg.configFile;
assert !(builtins.hasAttr "herdr/config.toml" empty.config.xdg.configFile);
assert !pkgs.stdenv.hostPlatform.isDarwin || !(builtins.tryEval nativeUI.config.assertions).success;
assert builtins.hasAttr "${enabled.config.xdg.stateHome}/herdr/client/endpoints.json"
  enabled.config.home.file;
assert
  !(builtins.hasAttr "${enabled.config.xdg.stateHome}/herdr/client/endpoint-selection.json" enabled.config.home.file);
assert enabled.config.programs.herdr.machines.example.label == "example";
assert enabled.config.programs.herdr.machines.example.session == "default";
assert !(enabled.config.home.activation ? herdrConfigMerge);
assert
  cfg.settings == { } && cfg.agentManifests == { } && cfg.remotes == { } && cfg.defaultRemote == null;
pkgs.runCommand "herdr-defaults" { } "touch $out"
