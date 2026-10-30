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
  claudeOwner = { lib, ... }: {
    options.programs.claude = {
      enable = lib.mkEnableOption "Claude";
      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      hooks.events = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
        default = { };
      };
    };
  };
  oldClaudeOwner = { lib, ... }: {
    options.programs.claude = {
      enable = lib.mkEnableOption "Claude";
      settings = lib.mkOption {
        type = lib.types.submodule { freeformType = lib.types.attrs; };
        default = { };
      };
    };
  };
  claude = evaluate {
    imports = [
      claudeOwner
      { programs.claude.hooks.events.SessionStart = [ { hooks = [ { command = "first"; } ]; } ]; }
      { programs.claude.hooks.events.SessionStart = [ { hooks = [ { command = "second"; } ]; } ]; }
    ];
    programs = {
      herdr = {
        enable = true;
        integrations.claude.enable = true;
      };
      claude = {
        enable = true;
        settings.hooks.SessionStart = [ { hooks = [ { command = "legacy"; } ]; } ];
      };
    };
  };
  oldClaude = evaluate {
    imports = [ oldClaudeOwner ];
    programs = {
      herdr = {
        enable = true;
        integrations.claude.enable = true;
      };
      claude.enable = true;
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
      qwen-code = {
        enable = lib.mkEnableOption "Qwen";
        nativeHooks = lib.mkOption {
          inherit (pkgs.formats.json { }) type;
          default = { };
        };
      };
      copilot-cli = {
        enable = lib.mkEnableOption "Copilot";
        nativeHooks = lib.mkOption {
          inherit (pkgs.formats.json { }) type;
          default = { };
        };
      };
      antigravity-cli = {
        nativeConfigDir = lib.mkOption {
          type = lib.types.str;
          default = ".gemini/config";
        };
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
            qwen.enable = true;
            copilot.enable = true;
          };
        };
        opencode = {
          enable = true;
          tuiSettings.plugin = [ "existing-tui" ];
          cliSettings.plugins = [ "existing-cli" ];
        };
        qwen-code.enable = true;
        copilot-cli = {
          enable = true;
          nativeHooks.SessionStart = [ { bash = "existing"; } ];
        };
        antigravity-cli = {
          nativeConfigDir = ".config/custom-agy";
          enable = true;
          nativeHooks.other.PreInvocation = [ { type = "command"; } ];
        };
      };
    }
  );
  externalTargets = [
    "devin"
    "droid"
    "kimi"
    "hermes"
    "qodercli"
    "cursor"
    "mastracode"
  ];
  ownerFormats = {
    devin = pkgs.formats.json { };
    droid = pkgs.formats.json { };
    kimi = pkgs.formats.toml { };
    hermes = pkgs.formats.yaml { };
    qodercli = pkgs.formats.json { };
    cursor = pkgs.formats.json { };
    mastracode = pkgs.formats.json { };
  };
  ownerConfigPaths = {
    devin = ".config/devin/config.json";
    droid = ".factory/settings.json";
    kimi = ".kimi-code/config.toml";
    hermes = ".hermes/config.yaml";
    qodercli = ".qoder/settings.json";
    cursor = ".cursor/hooks.json";
    mastracode = ".mastracode/hooks.json";
  };
  ownerOptions = lib.setAttrByPath [ "programs" "fixture" ] (
    lib.genAttrs externalTargets (name: {
      settings = lib.mkOption {
        inherit (ownerFormats.${name}) type;
        default = { };
      };
    })
  );
  owner = { config, lib, ... }: {
    options = ownerOptions;
    config.home.file = lib.mkMerge (
      lib.mapAttrsToList (
        name: format:
        lib.mkIf (config.programs.fixture.${name}.settings != { }) {
          "${ownerConfigPaths.${name}}".source =
            format.generate "fixture-${name}"
              config.programs.fixture.${name}.settings;
        }
      ) ownerFormats
    );
  };
  rendererModules = map (
    agent:
    catalog.mkRendererModule {
      inherit agent;
      settingsPath = [
        "programs"
        "fixture"
        agent
        "settings"
      ];
    }
  ) externalTargets;
  rendererFixture = evaluate {
    imports = [ owner ] ++ rendererModules;
    programs.herdr = {
      enable = true;
      integrations = lib.genAttrs externalTargets (_: {
        enable = true;
      });
    };
    programs.fixture = {
      devin.settings.hooks.SessionStart = [ { hooks = [ { command = "existing-devin"; } ]; } ];
      kimi.settings.hooks = [
        {
          event = "existing-kimi";
          command = "existing";
        }
      ];
      hermes.settings.plugins.enabled = [ "existing-hermes" ];
    };
  };
  singleRenderer = evaluate {
    imports = [ owner ] ++ rendererModules;
    programs.herdr = {
      enable = true;
      integrations.kimi.enable = true;
    };
  };
  withoutRenderer = evaluate {
    programs.herdr = {
      enable = true;
      integrations.hermes.enable = true;
    };
  };
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
assert valid claude;
assert !valid oldClaude;
assert builtins.length claude.programs.claude.hooks.events.SessionStart == 3;
assert
  claude.programs.claude.settings.hooks.SessionStart == [ { hooks = [ { command = "legacy"; } ]; } ];
assert lib.all
  (
    name:
    lib.any (
      entry: lib.any (hook: lib.hasInfix name hook.command) entry.hooks
    ) claude.programs.claude.hooks.events.SessionStart
  )
  [
    "first"
    "second"
    "herdr-agent-state.sh"
  ];
assert valid apps;
assert builtins.length apps.programs.opencode.tuiSettings.plugin == 2;
assert builtins.length apps.programs.opencode.cliSettings.plugins == 2;
assert apps.programs.antigravity-cli.nativeHooks ? other;
assert apps.programs.antigravity-cli.nativeHooks ? herdr;
assert lib.hasAttr ".config/custom-agy/hooks/herdr-agent-state.sh" apps.home.file;
assert lib.hasInfix "/.config/custom-agy/hooks/herdr-agent-state.sh"
  (builtins.head apps.programs.antigravity-cli.nativeHooks.herdr.PreInvocation).command;
assert builtins.length apps.programs.copilot-cli.nativeHooks.SessionStart == 2;
assert apps.programs.qwen-code.nativeHooks ? SessionStart;
assert builtins.length (builtins.attrNames apps.home.file) == 6;
assert valid rendererFixture;
assert valid singleRenderer;
assert lib.hasAttr ".kimi-code/hooks/herdr-agent-state.sh" singleRenderer.home.file;
assert lib.hasAttr ".kimi-code/config.toml" singleRenderer.home.file;
assert !(lib.hasAttr ".hermes/plugins/herdr-agent-state/plugin.yaml" singleRenderer.home.file);
assert !(lib.hasAttr ".hermes/config.yaml" singleRenderer.home.file);
assert !valid withoutRenderer;
assert builtins.length rendererFixture.programs.fixture.devin.settings.hooks.SessionStart == 2;
assert builtins.length rendererFixture.programs.fixture.kimi.settings.hooks == 13;
assert lib.elem "existing-hermes" rendererFixture.programs.fixture.hermes.settings.plugins.enabled;
assert lib.elem "herdr-agent-state"
  rendererFixture.programs.fixture.hermes.settings.plugins.enabled;
assert lib.all (name: lib.hasAttr name rendererFixture.home.file) [
  ".hermes/plugins/herdr-agent-state/plugin.yaml"
  ".hermes/plugins/herdr-agent-state/__init__.py"
  ".kimi-code/hooks/herdr-agent-state.sh"
];
assert lib.all (
  name: lib.hasAttr ownerConfigPaths.${name} rendererFixture.home.file
) externalTargets;
assert fragments.opencode.tui.plugin == [ "./herdr-tui-session.js" ];
assert fragments.opencode.cli.plugins == [ "./herdr-opencode" ];
assert fragments.claude.hooks.SessionStart != [ ];
pkgs.runCommand "herdr-integration-assets" { } ''
  ${lib.concatMapStringsSep "\n" (
    asset: ''test -f "${package}/share/herdr/integrations/${asset}"''
  ) allAssets}
  ${pkgs.python3}/bin/python3 - <<'PY'
  import json
  import os
  import socket
  import subprocess
  import tempfile

  with tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"]) as directory:
      for agent in ("claude", "grok"):
          path = os.path.join(directory, agent + ".sock")
          with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
              server.bind(path)
              server.listen(1)
              server.settimeout(3)
              env = {"PATH": "", "TMPDIR": directory, "HERDR_ENV": "1",
                     "HERDR_SOCKET_PATH": path, "HERDR_PANE_ID": "test-pane"}
              subprocess.run(
                  ["${lib.getExe pkgs.dash}", "${package}/share/herdr/integrations/" + agent + "/herdr-agent-state.sh", "session"],
                  input=json.dumps({"hook_event_name": "SessionStart", "session_id": "test-session"}),
                  text=True, env=env, check=True, timeout=5,
              )
              with server.accept()[0] as client:
                  request = json.loads(client.recv(8192))
              assert request["method"] == "pane.report_agent_session"
              assert request["params"]["agent_session_id"] == "test-session"
  PY
  touch "$out"
''
