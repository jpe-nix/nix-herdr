{ inputs, pkgs }:
let
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = {
          username = "test";
          homeDirectory = homeDir;
          stateVersion = "26.05";
        };
        programs.herdr = {
          enable = true;
          package = pkgs.hello;
          configDir = ".config/custom-herdr";
          server.enable = true;
          collie = {
            enable = true;
            package = pkgs.hello;
          };
        };
      }
    ];
  };
  cfg = home.config;
  socket = "${homeDir}/.config/custom-herdr/herdr.sock";
  herdrEnv =
    if pkgs.stdenv.hostPlatform.isDarwin then
      cfg.launchd.agents.herdr.config.EnvironmentVariables
    else
      cfg.systemd.user.services.herdr.Service.Environment;
  collieEnv =
    if pkgs.stdenv.hostPlatform.isDarwin then
      cfg.launchd.agents.collie.config.EnvironmentVariables
    else
      cfg.systemd.user.services.collie.Service.Environment;
  configPath = "${homeDir}/.config/custom-herdr/config.toml";
in
assert builtins.hasAttr ".config/collie/nix-config.toml" cfg.home.file;
assert
  if pkgs.stdenv.hostPlatform.isDarwin then
    builtins.elem "_exec-bridge" cfg.launchd.agents.collie.config.ProgramArguments
    && herdrEnv.HERDR_CONFIG_PATH == configPath
  else
    pkgs.lib.hasSuffix " _exec-bridge" cfg.systemd.user.services.collie.Service.ExecStart
    && builtins.elem "HERDR_CONFIG_PATH=${configPath}" herdrEnv;
assert
  if pkgs.stdenv.hostPlatform.isDarwin then
    herdrEnv.HERDR_SOCKET_PATH == socket
    && collieEnv.HERDR_SOCKET_PATH == socket
    && collieEnv.COLLIE_HOST == "127.0.0.1"
  else
    builtins.elem "HERDR_SOCKET_PATH=${socket}" herdrEnv
    && builtins.elem "HERDR_SOCKET_PATH=${socket}" collieEnv
    && builtins.elem "COLLIE_HOST=127.0.0.1" collieEnv;
pkgs.runCommand "herdr-services" { } "touch $out"
