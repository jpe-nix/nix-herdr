{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.herdr;
  toml = pkgs.formats.toml { };
  remote = lib.optionalAttrs (cfg.remotes != { } || cfg.defaultRemote != null) {
    remote = {
      hosts = cfg.remotes;
    }
    // lib.optionalAttrs (cfg.defaultRemote != null) { default = cfg.defaultRemote; };
  };
in
{
  config = lib.mkIf cfg.enable {
    home = {
      packages = lib.optional (cfg.package != null) cfg.package;
      file = {
        "${cfg.configDir}/config.toml".source = toml.generate "herdr-config.toml" (
          lib.recursiveUpdate remote cfg.settings
        );
      }
      // lib.mapAttrs' (
        name: value:
        lib.nameValuePair "${cfg.configDir}/agent-detection/${name}.toml" {
          source = toml.generate "herdr-agent-${name}.toml" value;
        }
      ) cfg.agentManifests;
      sessionVariables = {
        HERDR_CONFIG_PATH = "${config.home.homeDirectory}/${cfg.configDir}/config.toml";
        HERDR_SOCKET_PATH = "${config.home.homeDirectory}/${cfg.configDir}/herdr.sock";
      };
    };
  };
}
