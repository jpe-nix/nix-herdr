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
    HOME = home;
    HERDR_CONFIG_PATH = "${home}/${cfg.configDir}/config.toml";
    HERDR_SOCKET_PATH = "${home}/${cfg.configDir}/herdr.sock";
    XDG_CONFIG_HOME = config.xdg.configHome;
    XDG_STATE_HOME = config.xdg.stateHome;
    PATH = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
  };
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
          launchd.agents.herdr = {
            enable = true;
            config = {
              Label = "dev.herdr.server";
              ProgramArguments = [
                (lib.getExe cfg.package)
                "server"
              ];
              RunAtLoad = true;
              KeepAlive = true;
              ThrottleInterval = 30;
              EnvironmentVariables = env;
            };
          };
        })
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          systemd.user.services.herdr = {
            Unit.Description = "Herdr terminal server";
            Install.WantedBy = [ "default.target" ];
            Service = {
              ExecStart = "${lib.getExe cfg.package} server";
              Restart = "on-failure";
              Environment = lib.mapAttrsToList (name: value: "${name}=${value}") env;
            };
          };
        })
      ]
    ))
  ];
}
