{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.herdr;
in
{
  options.programs.herdr = {
    enable = lib.mkEnableOption "Herdr and its per-user server";
    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
      description = "Herdr TUI package.";
    };
    server.enable = lib.mkEnableOption "a Herdr systemd user service";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd.user.services.herdr = lib.mkIf cfg.server.enable {
      description = "Herdr terminal server";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} server";
        Restart = "on-failure";
        Environment = [
          "HERDR_CONFIG_PATH=%h/.config/herdr/config.toml"
          "HERDR_SOCKET_PATH=%h/.config/herdr/herdr.sock"
        ];
      };
    };
  };
}
