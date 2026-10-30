{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.herdr;
  home = config.home.homeDirectory;
  env = {
    PATH = lib.concatStringsSep ":" [
      "${config.home.profileDirectory}/bin"
      "/etc/profiles/per-user/${config.home.username}/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ];
  }
  // cfg.server.environment
  // {
    HOME = home;
    HERDR_CONFIG_PATH = "${home}/${cfg.configDir}/config.toml";
    HERDR_SOCKET_PATH = "${home}/${cfg.configDir}/herdr.sock";
    XDG_CONFIG_HOME = config.xdg.configHome;
    XDG_STATE_HOME = config.xdg.stateHome;
  };
  command = cfg.server.launchPrefix ++ [
    (lib.getExe cfg.package)
    "server"
  ];
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.enable && cfg.server.enable) || cfg.package != null;
          message = "The Herdr user server requires programs.herdr.package.";
        }
      ];
    }
    (lib.mkIf (cfg.enable && cfg.server.enable && cfg.package != null) (
      lib.mkMerge [
        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          home.file."Library/Logs/herdr/.keep".text = "";
          launchd.agents.herdr = {
            enable = true;
            config = {
              Label = "dev.herdr.server";
              ProgramArguments = command;
              RunAtLoad = true;
              KeepAlive = true;
              ThrottleInterval = 30;
              ProcessType = "Background";
              StandardOutPath = "${home}/Library/Logs/herdr/herdr.log";
              StandardErrorPath = "${home}/Library/Logs/herdr/herdr.error.log";
              EnvironmentVariables = env;
            };
          };
        })
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          systemd.user.services.herdr = {
            Unit.Description = "Herdr terminal server";
            Install.WantedBy = [ "default.target" ];
            Service = {
              ExecStart =
                (import (pkgs.path + "/nixos/lib/utils.nix") {
                  inherit lib config pkgs;
                }).escapeSystemdExecArgs
                  command;
              Restart = "on-failure";
              Environment = lib.mapAttrsToList (name: value: "${name}=${value}") env;
            };
          };
        })
      ]
    ))
  ];
}
