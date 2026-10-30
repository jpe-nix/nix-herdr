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
        };
      }
    ];
  };
in
assert !cfg.enable;
assert !cfg.server.enable;
assert !cfg.collie.enable;
assert !cfg.nativeUI.enable;
assert builtins.all (integration: !integration.enable) (builtins.attrValues cfg.integrations);
assert !enabled.config.programs.herdr.server.enable;
assert builtins.hasAttr ".config/herdr/config.toml" enabled.config.home.file;
assert !(enabled.config.home.activation ? herdrConfigMerge);
assert
  cfg.settings == { } && cfg.agentManifests == { } && cfg.remotes == { } && cfg.defaultRemote == null;
pkgs.runCommand "herdr-defaults" { } "touch $out"
