{ inputs }:
{ lib, pkgs, ... }:
let
  toml = pkgs.formats.toml { };
in
{
  options.programs.herdr = {
    enable = lib.mkEnableOption "Herdr terminal workspace manager";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = inputs.herdr-upstream.packages.${pkgs.stdenv.hostPlatform.system}.herdr-tui;
      defaultText = lib.literalExpression "herdr-upstream.packages.\${system}.herdr-tui";
      description = "Herdr TUI package, or null when supplied outside Home Manager.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = ".config/herdr";
      description = "Home-relative directory for the configuration and socket.";
    };
    settings = lib.mkOption {
      inherit (toml) type;
      default = { };
      description = "Herdr TOML settings. Values enter the Nix store and must not contain secrets.";
    };
    agentManifests = lib.mkOption {
      type = lib.types.attrsOf toml.type;
      default = { };
      description = "Agent detection manifests keyed by name.";
    };
    remotes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Legacy named SSH remotes.";
    };
    defaultRemote = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default legacy SSH remote.";
    };
    server.enable = lib.mkEnableOption "the Herdr user server";
  };
}
