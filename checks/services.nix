{ inputs, pkgs }:
let
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
  testHome = {
    username = "test";
    homeDirectory = homeDir;
    stateVersion = "26.05";
  };
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = testHome;
        xdg.configHome = "${homeDir}/.config/custom";
        programs.herdr = {
          enable = true;
          package = pkgs.hello;
          agentManifests.example.id = "example";
          server = {
            enable = true;
            launchPrefix = [
              "/opt/example/launcher"
              "a $b %c"
            ];
            environment = {
              TEST_ENV = "value";
              PATH = "/opt/homebrew/bin:${homeDir}/.local/bin";
              HOME = "/ignored/home";
              HERDR_SOCKET_PATH = "/ignored/socket";
              HERDR_CONFIG_PATH = "/ignored/config";
            };
          };
          collie = {
            enable = true;
            package = pkgs.hello;
            settings.network.host = "127.0.0.2";
            settings.mux.mux = "tmux";
            environment = {
              PATH = "/consumer/bin";
              COLLIE_HOST = "127.0.0.3";
              HOME = "/ignored/home";
              COLLIE_CONFIG = "/consumer/config";
              HERDR_SOCKET_PATH = "/ignored/socket";
              COLLIE_MUX = "consumer";
            };
          };
        };
      }
    ];
  };
  defaultHome = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home = testHome;
        programs.herdr = {
          enable = true;
          package = pkgs.hello;
          server.enable = true;
          collie = {
            enable = true;
            package = pkgs.hello;
            settings.network.host = "127.0.0.2";
          };
        };
      }
    ];
  };
  cfg = home.config;
  socket = "${homeDir}/.config/custom/herdr/herdr.sock";
  herdrEnv =
    if pkgs.stdenv.hostPlatform.isDarwin then
      cfg.launchd.agents.herdr.config.EnvironmentVariables
    else
      cfg.systemd.user.services.herdr.Service.Environment;
  configPath = "${homeDir}/.config/custom/herdr/config.toml";
  command = [
    "/opt/example/launcher"
    "a $b %c"
    (pkgs.lib.getExe pkgs.hello)
    "server"
  ];
  defaultEnv =
    if pkgs.stdenv.hostPlatform.isDarwin then
      defaultHome.config.launchd.agents.herdr.config.EnvironmentVariables
    else
      defaultHome.config.systemd.user.services.herdr.Service.Environment;
in
assert
  if pkgs.stdenv.hostPlatform.isDarwin then
    pkgs.lib.hasInfix "/etc/profiles/per-user/test/bin" defaultEnv.PATH
    && pkgs.lib.hasInfix "/usr/local/bin" defaultEnv.PATH
  else
    builtins.any (
      value:
      pkgs.lib.hasPrefix "PATH=" value
      && pkgs.lib.hasInfix "/etc/profiles/per-user/test/bin" value
      && pkgs.lib.hasInfix "/usr/local/bin" value
    ) defaultEnv;
assert builtins.hasAttr "${homeDir}/.config/custom/herdr/agent-detection/example.toml"
  cfg.home.file;
assert
  if pkgs.stdenv.hostPlatform.isDarwin then
    herdrEnv.HERDR_CONFIG_PATH == configPath
  else
    builtins.elem "HERDR_CONFIG_PATH=${configPath}" herdrEnv;
assert
  if pkgs.stdenv.hostPlatform.isDarwin then
    herdrEnv.HERDR_SOCKET_PATH == socket
    && herdrEnv.TEST_ENV == "value"
    && herdrEnv.PATH == "/opt/homebrew/bin:${homeDir}/.local/bin"
    && herdrEnv.HOME == homeDir
    && cfg.launchd.agents.herdr.config.ProgramArguments == command
    && cfg.launchd.agents.herdr.config.ProcessType == "Background"
    && cfg.launchd.agents.herdr.config.StandardOutPath == "${homeDir}/Library/Logs/herdr/herdr.log"
    &&
      cfg.launchd.agents.herdr.config.StandardErrorPath == "${homeDir}/Library/Logs/herdr/herdr.error.log"
  else
    builtins.elem "HERDR_SOCKET_PATH=${socket}" herdrEnv
    && builtins.elem "TEST_ENV=value" herdrEnv
    && builtins.elem "PATH=/opt/homebrew/bin:${homeDir}/.local/bin" herdrEnv
    && builtins.elem "HOME=${homeDir}" herdrEnv
    && builtins.elem (
      (import (pkgs.path + "/nixos/lib/utils.nix") {
        inherit (pkgs) lib;
        inherit pkgs;
        config = cfg;
      }).escapeSystemdExecArgs
        command
    ) cfg.systemd.user.services.herdr.Service.ExecStart;
import ./collie-config.nix {
  inherit
    inputs
    pkgs
    cfg
    socket
    homeDir
    ;
  defaultConfig = defaultHome.config;
}
