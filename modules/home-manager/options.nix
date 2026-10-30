{ inputs }:
{ lib, pkgs, ... }:
let
  toml = pkgs.formats.toml { };
  machineType = lib.types.submodule (
    { name, ... }: {
      options = {
        id = lib.mkOption {
          type = lib.types.strMatching "[0-9a-f]{32}";
          default = builtins.substring 0 32 (builtins.hashString "sha256" name);
          description = "Stable machine ID, derived from the attribute name by default.";
        };
        label = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Machine label.";
        };
        target = lib.mkOption {
          type = lib.types.str;
          description = "OpenSSH host alias or target.";
        };
        session = lib.mkOption {
          type = lib.types.str;
          default = "default";
          description = "Remote Herdr session.";
        };
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Connect at client startup.";
        };
      };
    }
  );
in
{
  options.programs.herdr = {
    agentManifests = lib.mkOption {
      type = lib.types.attrsOf toml.type;
      default = { };
      description = "Agent detection manifests keyed by name.";
    };
    remotes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Deprecated legacy SSH remotes; use machines instead.";
    };
    defaultRemote = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Deprecated legacy default remote; machine selection is managed by Herdr.";
    };
    machines = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf machineType);
      default = null;
      description = "Declarative saved SSH machines, or null to leave the catalog unmanaged.";
    };
    server = {
      enable = lib.mkEnableOption "the Herdr user server";
      launchPrefix = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Command and arguments prepended to the Herdr server executable. Values are stored in the Nix store and must not contain secrets.";
      };
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Nonsecret server environment values, including an optional PATH. HOME, Herdr configuration, socket, and XDG paths remain managed by this module.";
      };
    };
  };
  config.programs.herdr.package =
    lib.mkDefault
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
}
