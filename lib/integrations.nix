{
  lib,
  bash ? "bash",
  sh ? "sh",
}:
let
  command =
    shell: path: action:
    "${shell} ${lib.escapeShellArg path} ${action}";
  hook = path: action: {
    type = "command";
    command = command bash path action;
    timeout = 10;
  };
  wrapped = path: action: { hooks = [ (hook path action) ]; };
  matched = path: timeout: {
    matcher = "*";
    hooks = [ ((hook path "session") // { inherit timeout; }) ];
  };
  session = path: { SessionStart = [ (wrapped path "session") ]; };
  names = [
    "pi"
    "omp"
    "claude"
    "codex"
    "copilot"
    "devin"
    "droid"
    "kimi"
    "opencode"
    "kilo"
    "hermes"
    "qodercli"
    "cursor"
    "mastracode"
    "antigravity-cli"
    "grok"
    "qwen"
  ];
  files = {
    pi = {
      ".pi/agent/extensions/herdr-agent-state.ts" = "pi/herdr-agent-state.ts";
    };
    omp = {
      ".omp/agent/extensions/herdr-omp-agent-state.ts" = "omp/herdr-agent-state.ts";
    };
    claude = {
      ".claude/hooks/herdr-agent-state.sh" = "claude/herdr-agent-state.sh";
    };
    codex = {
      ".codex/herdr-agent-state.sh" = "codex/herdr-agent-state.sh";
    };
    copilot = {
      ".copilot/hooks/herdr-agent-state.sh" = "copilot/herdr-agent-state.sh";
    };
    devin = {
      ".config/devin/herdr-agent-state.sh" = "devin/herdr-agent-state.sh";
    };
    droid = {
      ".factory/hooks/herdr-agent-state.sh" = "droid/herdr-agent-state.sh";
    };
    kimi = {
      ".kimi-code/hooks/herdr-agent-state.sh" = "kimi/herdr-agent-state.sh";
    };
    opencode = {
      ".config/opencode/plugins/herdr-agent-state.js" = "opencode/herdr-agent-state.js";
      ".config/opencode/herdr-tui-session.js" = "opencode/herdr-tui-session.js";
      ".config/opencode/herdr-opencode/tui.js" = "opencode/tui.js";
    };
    kilo = {
      ".config/kilo/plugin/herdr-agent-state.js" = "kilo/herdr-agent-state.js";
    };
    hermes = {
      ".hermes/plugins/herdr-agent-state/plugin.yaml" = "hermes/plugin.yaml";
      ".hermes/plugins/herdr-agent-state/__init__.py" = "hermes/__init__.py";
    };
    qodercli = {
      ".qoder/hooks/herdr-agent-state.sh" = "qodercli/herdr-agent-state.sh";
    };
    cursor = {
      ".cursor/herdr-agent-state.sh" = "cursor/herdr-agent-state.sh";
    };
    mastracode = {
      ".mastracode/hooks/herdr-agent-state.sh" = "mastracode/herdr-agent-state.sh";
    };
    antigravity-cli = {
      ".gemini/config/hooks/herdr-agent-state.sh" = "antigravity_cli/herdr-agent-state.sh";
    };
    grok = {
      ".grok/hooks/herdr-agent-state.sh" = "grok/herdr-agent-state.sh";
    };
    qwen = {
      ".qwen/hooks/herdr-agent-session.sh" = "qwen/herdr-agent-session.sh";
    };
  };
  fragments =
    home:
    let
      p = relative: "${home}/${relative}";
      kimiPath = p ".kimi-code/hooks/herdr-agent-state.sh";
      kimiEntry =
        event: action: matcher:
        {
          inherit event;
          command = command bash kimiPath action;
          timeout = 10;
        }
        // lib.optionalAttrs (matcher != null) { inherit matcher; };
      ask = "^AskUserQuestion$";
      mastraPath = p ".mastracode/hooks/herdr-agent-state.sh";
      mastra = event: action: {
        name = event;
        value = [
          {
            type = "command";
            command = command bash mastraPath action;
            timeout = 10000;
            description = "Report MastraCode agent state to Herdr";
          }
        ];
      };
    in
    {
      claude.hooks.SessionStart = [
        {
          matcher = "^(startup|resume|clear|compact|fork)$";
          hooks = [ (hook (p ".claude/hooks/herdr-agent-state.sh") "session") ];
        }
      ];
      codex.hooks = session (p ".codex/herdr-agent-state.sh");
      copilot.hooks.SessionStart = [
        {
          type = "command";
          bash = "${bash} ${lib.escapeShellArg (p ".copilot/hooks/herdr-agent-state.sh")}";
          timeoutSec = 10;
        }
      ];
      devin.hooks = lib.genAttrs [
        "SessionStart"
        "UserPromptSubmit"
        "PreToolUse"
        "PostToolUse"
        "PermissionRequest"
        "Stop"
      ] (_: [ (wrapped (p ".config/devin/herdr-agent-state.sh") "session") ]);
      droid.hooks = session (p ".factory/hooks/herdr-agent-state.sh");
      kimi.hooks = [
        (kimiEntry "SessionStart" "session" null)
        (kimiEntry "UserPromptSubmit" "working" null)
        (kimiEntry "PreToolUse" "working" "^(?!AskUserQuestion$).*$")
        (kimiEntry "PreToolUse" "blocked" ask)
        (kimiEntry "PostToolUse" "working" ask)
        (kimiEntry "PostToolUseFailure" "working" ask)
        (kimiEntry "SubagentStart" "working" null)
        (kimiEntry "PreCompact" "working" null)
        (kimiEntry "PermissionRequest" "blocked" null)
        (kimiEntry "PermissionResult" "working" null)
        (kimiEntry "Stop" "idle" null)
        (kimiEntry "Interrupt" "idle" null)
      ];
      opencode = {
        tui.plugin = [ "./herdr-tui-session.js" ];
        cli.plugins = [ "./herdr-opencode" ];
      };
      hermes.plugins.enabled = [ "herdr-agent-state" ];
      qodercli.hooks.SessionStart = [ (matched (p ".qoder/hooks/herdr-agent-state.sh") 10) ];
      qwen.hooks.SessionStart = [ (matched (p ".qwen/hooks/herdr-agent-session.sh") 10000) ];
      cursor = {
        version = 1;
        hooks.sessionStart = [ { command = command bash (p ".cursor/herdr-agent-state.sh") "session"; } ];
      };
      mastracode = builtins.listToAttrs (
        map (x: mastra (builtins.elemAt x 0) (builtins.elemAt x 1)) [
          [
            "SessionStart"
            "session"
          ]
          [
            "UserPromptSubmit"
            "working"
          ]
          [
            "AgentStart"
            "working"
          ]
          [
            "PreToolUse"
            "working"
          ]
          [
            "PermissionRequest"
            "blocked"
          ]
          [
            "PermissionResult"
            "working"
          ]
          [
            "SubagentStart"
            "working"
          ]
          [
            "SubagentEnd"
            "working"
          ]
          [
            "Interrupt"
            "idle"
          ]
          [
            "AgentEnd"
            "idle"
          ]
          [
            "Stop"
            "idle"
          ]
        ]
      );
      antigravity-cli.herdr.PreInvocation = [
        (hook (p ".gemini/config/hooks/herdr-agent-state.sh") "session")
      ];
      grok.hooks.SessionStart = [
        {
          hooks = [
            (
              (hook (p ".grok/hooks/herdr-agent-state.sh") "session")
              // {
                command = command sh (p ".grok/hooks/herdr-agent-state.sh") "session";
              }
            )
          ];
        }
      ];
    };
  externalRendererAgents = [
    "devin"
    "droid"
    "kimi"
    "hermes"
    "qodercli"
    "cursor"
    "mastracode"
  ];
  # Import next to an app-owned renderer. settingsPath names its complete
  # JSON, TOML, or YAML settings option; the option must merge list entries.
  # Destination paths follow the upstream default HOME layout.
  mkRendererModule =
    { agent, settingsPath }:
    assert lib.assertMsg (builtins.elem agent externalRendererAgents)
      "Herdr: ${agent} is not a target for external renderer modules.";
    assert lib.assertMsg (
      settingsPath != [ ] && lib.all builtins.isString settingsPath
    ) "Herdr: settingsPath must be a non-empty list of option names.";
    { config, pkgs, ... }:
    {
      options.programs.herdr._integrationRenderers.${agent} = lib.mkOption {
        type = lib.types.bool;
        default = true;
        readOnly = true;
        internal = true;
        description = "An app-owned renderer module was imported for ${agent}.";
      };
      config =
        lib.mkIf (config.programs.herdr.enable && config.programs.herdr.integrations.${agent}.enable)
          (
            lib.setAttrByPath settingsPath
              (
                (import ./integrations.nix {
                  inherit lib;
                  bash = lib.getExe pkgs.bash;
                  sh = lib.getExe pkgs.dash;
                }).fragments
                  config.home.homeDirectory
              ).${agent}
          );
    };
in
{
  inherit
    names
    files
    fragments
    mkRendererModule
    ;
}
