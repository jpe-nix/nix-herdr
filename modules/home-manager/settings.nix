{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.herdr;
  toml = pkgs.formats.toml { };
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.remotes == { } && cfg.defaultRemote == null;
        message = "Herdr no longer supports remotes or defaultRemote; migrate to programs.herdr.machines and select the machine in the client.";
      }
    ];
    home = {
      file =
        lib.optionalAttrs (cfg.machines != null) {
          "${config.xdg.stateHome}/herdr/client/endpoints.json".source =
            (pkgs.formats.json { }).generate "herdr-endpoints.json"
              {
                version = 1;
                ssh = lib.attrValues cfg.machines;
              };
        }
        // lib.mapAttrs' (
          name: value:
          lib.nameValuePair "${config.xdg.configHome}/herdr/agent-detection/${name}.toml" {
            source = toml.generate "herdr-agent-${name}.toml" value;
          }
        ) cfg.agentManifests;
      sessionVariables = {
        HERDR_CONFIG_PATH = "${config.xdg.configHome}/herdr/config.toml";
        HERDR_SOCKET_PATH = "${config.xdg.configHome}/herdr/herdr.sock";
      };
    };
  };
}
