{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.herdr;
  inherit (cfg) collie;
  env = {
    PATH = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
  }
  // collie.environment
  // {
    HOME = config.home.homeDirectory;
    HERDR_SOCKET_PATH = "${config.xdg.configHome}/herdr/herdr.sock";
  };
in
{
  options.programs.herdr.collie = {
    enable = lib.mkEnableOption "the Collie bridge user service";
    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.collie-upstream.packages.${pkgs.stdenv.hostPlatform.system}.collie;
      description = "Collie package.";
    };
    settings = lib.mkOption {
      inherit ((pkgs.formats.toml { })) type;
      default = { };
      description = "Nonsecret Collie TOML settings, stored in the Nix store.";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Nonsecret service-only environment values, including paths to runtime secret files where supported by Collie. Use settings for values shared with the CLI.";
    };
  };
  config = lib.mkIf (cfg.enable && collie.enable) (
    lib.mkMerge [
      {
        home.packages = [ collie.package ];
        programs.herdr.collie.settings.mux.mux = lib.mkDefault "herdr";
        home.file.".collie/config.toml".source =
          (pkgs.formats.toml { }).generate "collie-config.toml"
            collie.settings;
      }
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        systemd.user.services.collie = {
          Unit.Description = "Collie bridge";
          Install.WantedBy = [ "default.target" ];
          Service = {
            ExecStart = "${lib.getExe collie.package} _exec-bridge";
            Restart = "on-failure";
            Environment = lib.mapAttrsToList (name: value: "${name}=${value}") env;
          };
        };
      })
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        launchd.agents.collie = {
          enable = true;
          config = {
            Label = "herdr.collie";
            ProgramArguments = [
              (lib.getExe collie.package)
              "_exec-bridge"
            ];
            RunAtLoad = true;
            KeepAlive = true;
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/collie.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/collie.error.log";
            EnvironmentVariables = env;
          };
        };
      })
    ]
  );
}
