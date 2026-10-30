_:
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  catalog = import ../../lib/integrations.nix {
    inherit lib;
    bash = lib.getExe pkgs.bash;
    sh = lib.getExe pkgs.dash;
  };
  cfg = config.programs.herdr;
  selected = name: cfg.integrations.${name}.enable;
  active = name: cfg.enable && selected name;
  available = path: lib.hasAttrByPath path options;
  claudeEventsPath = [
    "programs"
    "claude"
    "hooks"
    "events"
  ];
  claudeHookOption =
    if available claudeEventsPath then lib.getAttrFromPath claudeEventsPath options else null;
  claudeHookType = if claudeHookOption == null then null else claudeHookOption.type;
  claudeAvailable =
    claudeHookType != null
    && claudeHookType.name == "attrsOf"
    && (claudeHookType.nestedTypes.elemType.name or null) == "listOf"
    && (claudeHookType.nestedTypes.elemType.nestedTypes.elemType.name or null) == "attrs";
  codexAvailable = available [
    "programs"
    "codex"
    "hooks"
    "events"
  ];
  opencodeAvailable =
    available [
      "programs"
      "opencode"
      "tuiSettings"
    ]
    && available [
      "programs"
      "opencode"
      "cliSettings"
    ];
  qwenAvailable = available [
    "programs"
    "qwen-code"
    "nativeHooks"
  ];
  copilotAvailable = available [
    "programs"
    "copilot-cli"
    "nativeHooks"
  ];
  agyAvailable = available [
    "programs"
    "antigravity-cli"
    "nativeHooks"
  ];
  agyDir =
    if agyAvailable then
      config.programs.antigravity-cli.nativeConfigDir or ".gemini/config"
    else
      ".gemini/config";
  opencodeDir =
    if opencodeAvailable then
      config.programs.opencode.configDir or ".config/opencode"
    else
      ".config/opencode";
  claudeDir = if claudeAvailable then config.programs.claude.configDir or ".claude" else ".claude";
  claudePath = "${config.home.homeDirectory}/${claudeDir}/hooks/herdr-agent-state.sh";
  claudeHooks = {
    SessionStart = [
      {
        matcher = "^(startup|resume|clear|compact|fork)$";
        hooks = [
          {
            type = "command";
            command = "${lib.getExe pkgs.bash} ${lib.escapeShellArg claudePath} session";
            timeout = 10;
          }
        ];
      }
    ];
  };
  fragments = catalog.fragments config.home.homeDirectory;
  direct = [
    "pi"
    "omp"
    "kilo"
    "grok"
  ];
  managed = direct ++ [
    "claude"
    "codex"
    "opencode"
    "antigravity-cli"
    "copilot"
    "qwen"
  ];
  unsupported = builtins.filter (name: !(builtins.elem name managed)) catalog.names;
  fileFor = destination: asset: {
    name =
      if destination == ".claude/hooks/herdr-agent-state.sh" then
        "${claudeDir}/hooks/herdr-agent-state.sh"
      else if lib.hasPrefix ".gemini/config/" destination then
        "${agyDir}/${lib.removePrefix ".gemini/config/" destination}"
      else if lib.hasPrefix ".config/opencode/" destination then
        "${opencodeDir}/${lib.removePrefix ".config/opencode/" destination}"
      else
        destination;
    value = {
      source = "${cfg.package}/share/herdr/integrations/${asset}";
      executable = lib.hasSuffix ".sh" destination;
    };
  };
  filesFor = name: lib.mapAttrs' fileFor catalog.files.${name};
in
{
  options.programs.herdr.integrations = lib.genAttrs catalog.names (name: {
    enable = lib.mkEnableOption "the Herdr ${name} integration";
  });

  config = lib.mkMerge [
    {
      assertions =
        (map (name: {
          assertion =
            !active name
            || available [
              "programs"
              "herdr"
              "_integrationRenderers"
              name
            ];
          message = "programs.herdr.integrations.${name} requires an app-owned renderer. Import lib.integrations.mkRendererModule with the target and an existing app settings option.";
        }) unsupported)
        ++ [
          {
            assertion = !(cfg.enable && lib.any selected catalog.names) || cfg.package != null;
            message = "Herdr integrations require programs.herdr.package with bundled integration assets.";
          }
          {
            assertion = !active "claude" || claudeAvailable;
            message = "Herdr Claude integration requires nix-claude-code with its typed, mergeable programs.claude.hooks.events option.";
          }
          {
            assertion = !active "opencode" || opencodeAvailable;
            message = "Herdr OpenCode integration requires app-owned tuiSettings and cliSettings renderers.";
          }
          {
            assertion = !active "antigravity-cli" || agyAvailable;
            message = "Herdr Antigravity CLI integration requires the app-owned nativeHooks renderer.";
          }
          {
            assertion = !active "opencode" || (opencodeAvailable && config.programs.opencode.enable);
            message = "Enable programs.opencode to render Herdr plugins.";
          }
          {
            assertion = !active "antigravity-cli" || (agyAvailable && config.programs.antigravity-cli.enable);
            message = "Enable programs.antigravity-cli to render the Herdr hook.";
          }
          {
            assertion = !active "qwen" || (qwenAvailable && config.programs.qwen-code.enable);
            message = "Herdr Qwen integration requires enabled programs.qwen-code and its nativeHooks extension renderer.";
          }
          {
            assertion = !active "copilot" || (copilotAvailable && config.programs.copilot-cli.enable);
            message = "Herdr Copilot integration requires enabled programs.copilot-cli and its nativeHooks renderer.";
          }
          {
            assertion = !active "codex" || codexAvailable;
            message = "Herdr Codex integration requires the programs.codex.hooks.events renderer from nix-ai.";
          }
          {
            assertion = !active "claude" || (claudeAvailable && config.programs.claude.enable);
            message = "Enable programs.claude to render the Herdr Claude hook.";
          }
          {
            assertion = !active "codex" || (codexAvailable && config.programs.codex.enable);
            message = "Enable programs.codex to render the Herdr Codex hook.";
          }
        ];
    }
    (lib.mkMerge (
      map (
        name: lib.mkIf (active name && cfg.package != null) { home.file = filesFor name; }
      ) catalog.names
    ))
    (lib.mkIf (active "grok" && cfg.package != null) {
      home.file.".grok/hooks/herdr.json".source =
        pkgs.writers.writeJSON "herdr-grok-hooks.json" fragments.grok;
    })
    (lib.optionalAttrs claudeAvailable (
      lib.mkIf (active "claude") {
        programs.claude.hooks.events = claudeHooks;
      }
    ))
    (lib.optionalAttrs opencodeAvailable (
      lib.mkIf (active "opencode") {
        programs.opencode = {
          tuiSettings.plugin = fragments.opencode.tui.plugin;
          cliSettings.plugins = fragments.opencode.cli.plugins;
        };
      }
    ))
    (lib.optionalAttrs agyAvailable (
      lib.mkIf (active "antigravity-cli") {
        programs.antigravity-cli.nativeHooks = lib.recursiveUpdate fragments.antigravity-cli {
          herdr.PreInvocation = map (
            entry:
            entry
            // {
              command =
                lib.replaceStrings
                  [ "${config.home.homeDirectory}/.gemini/config/" ]
                  [ "${config.home.homeDirectory}/${agyDir}/" ]
                  entry.command;
            }
          ) fragments.antigravity-cli.herdr.PreInvocation;
        };
      }
    ))
    (lib.optionalAttrs qwenAvailable (
      lib.mkIf (active "qwen") { programs.qwen-code.nativeHooks = fragments.qwen.hooks; }
    ))
    (lib.optionalAttrs copilotAvailable (
      lib.mkIf (active "copilot") { programs.copilot-cli.nativeHooks = fragments.copilot.hooks; }
    ))
    (lib.optionalAttrs codexAvailable (
      lib.mkIf (active "codex") {
        programs.codex.hooks.events = fragments.codex.hooks;
      }
    ))
  ];
}
