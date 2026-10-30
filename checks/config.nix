{
  inputs,
  pkgs,
  package,
}:
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
        programs.herdr = {
          enable = true;
          inherit package;
          settings.theme.name = "nord";
        };
      }
    ];
  };
  configFile = home.config.home.file.".config/herdr/config.toml".source;
in
pkgs.runCommand "herdr-config-check" { } ''
  HERDR_CONFIG_PATH=${configFile} ${pkgs.lib.getExe package} config check > "$out"
''
