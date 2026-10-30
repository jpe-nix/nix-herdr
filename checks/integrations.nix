{
  lib,
  pkgs,
  package,
}:
let
  catalog = import ../lib/integrations.nix { inherit lib; };
  fragments = catalog.fragments "/home/test";
  stub = { lib, ... }: {
    options = {
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
      home.homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/test";
      };
      home.file = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      programs = {
        herdr.enable = lib.mkEnableOption "Herdr";
        herdr.package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = package;
        };
        codex.enable = lib.mkEnableOption "Codex";
        codex.hooks.events = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
          default = { };
        };
      };
    };
  };
  evaluate =
    extra:
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        stub
        (import ../modules/home-manager/integrations.nix { inputs = { }; })
        extra
      ];
    }).config;
  off = evaluate { programs.herdr.enable = true; };
  codex = evaluate {
    programs = {
      herdr = {
        enable = true;
        integrations.codex.enable = true;
      };
      codex = {
        enable = true;
        hooks.events.SessionStart = [ { hooks = [ { command = "existing"; } ]; } ];
      };
    };
  };
  missing = evaluate {
    programs.herdr = {
      enable = true;
      integrations.opencode.enable = true;
    };
  };
  appOwners = { lib, pkgs, ... }: {
    options.programs = {
      opencode = {
        enable = lib.mkEnableOption "OpenCode";
        configDir = lib.mkOption {
          type = lib.types.str;
          default = ".config/opencode";
        };
        tuiSettings = lib.mkOption {
          inherit (pkgs.formats.json { }) type;
          default = { };
        };
        cliSettings = lib.mkOption {
          inherit (pkgs.formats.json { }) type;
          default = { };
        };
      };
      antigravity-cli = {
        enable = lib.mkEnableOption "Antigravity";
        nativeHooks = lib.mkOption {
          inherit (pkgs.formats.json { }) type;
          default = { };
        };
      };
    };
  };
  apps = evaluate (
    { ... }: {
      imports = [ appOwners ];
      programs = {
        herdr = {
          enable = true;
          integrations = {
            opencode.enable = true;
            antigravity-cli.enable = true;
          };
        };
        opencode = {
          enable = true;
          tuiSettings.plugin = [ "existing-tui" ];
          cliSettings.plugins = [ "existing-cli" ];
        };
        antigravity-cli = {
          enable = true;
          nativeHooks.other.PreInvocation = [ { type = "command"; } ];
        };
      };
    }
  );
  allAssets = lib.concatLists (map (name: builtins.attrValues catalog.files.${name}) catalog.names);
  valid = c: lib.all (a: a.assertion) c.assertions;
in
assert lib.all (name: !off.programs.herdr.integrations.${name}.enable) catalog.names;
assert off.home.file == { };
assert valid off;
assert valid codex;
assert builtins.length codex.programs.codex.hooks.events.SessionStart == 2;
assert builtins.attrNames codex.home.file == [ ".codex/herdr-agent-state.sh" ];
assert !valid missing;
assert valid apps;
assert builtins.length apps.programs.opencode.tuiSettings.plugin == 2;
assert builtins.length apps.programs.opencode.cliSettings.plugins == 2;
assert apps.programs.antigravity-cli.nativeHooks ? other;
assert apps.programs.antigravity-cli.nativeHooks ? herdr;
assert builtins.length (builtins.attrNames apps.home.file) == 4;
assert fragments.opencode.tui.plugin == [ "./herdr-tui-session.js" ];
assert fragments.opencode.cli.plugins == [ "./herdr-opencode" ];
assert fragments.claude.hooks.SessionStart != [ ];
pkgs.runCommand "herdr-integration-assets" { } ''
  ${lib.concatMapStringsSep "\n" (
    asset: ''test -f "${package}/share/herdr/integrations/${asset}"''
  ) allAssets}
  touch "$out"
''
