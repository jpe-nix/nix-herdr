_:
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  catalog = import ../../lib/integrations.nix { inherit lib; };
  cfg = config.programs.herdr;
  selected = name: cfg.integrations.${name}.enable;
  active = name: cfg.enable && selected name;
  available = path: lib.hasAttrByPath path options;
  claudeSource = config._module.args.herdrClaudeCode or null;
  claudeAvailable =
    available [
      "programs"
      "claude"
      "settings"
    ]
    && claudeSource != null
    && builtins.pathExists "${claudeSource}/lib/typed-hooks.nix";
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
  agyAvailable = available [
    "programs"
    "antigravity-cli"
    "nativeHooks"
  ];
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
            command = "bash ${lib.escapeShellArg claudePath} session";
            timeout = 10;
          }
        ];
      }
    ];
  };
  typedClaudeHooks = import "${claudeSource}/lib/typed-hooks.nix" {
    inherit lib;
    cfg = config.programs.claude;
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
  ];
  unsupported = builtins.filter (name: !(builtins.elem name managed)) catalog.names;
  fileFor = destination: asset: {
    name =
      if destination == ".claude/hooks/herdr-agent-state.sh" then
        "${claudeDir}/hooks/herdr-agent-state.sh"
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
          assertion = !active name;
          message = "programs.herdr.integrations.${name} requires an app-owned configuration renderer. Consume lib.integrations.fragments and lib.integrations.files with that renderer; no shared app config is overwritten.";
        }) unsupported)
        ++ [
          {
            assertion = !(cfg.enable && lib.any selected catalog.names) || cfg.package != null;
            message = "Herdr integrations require programs.herdr.package with bundled integration assets.";
          }
          {
            assertion = !active "claude" || claudeAvailable;
            message = "Herdr Claude integration requires the nix-claude-code renderer and _module.args.herdrClaudeCode pointing to its source with lib/typed-hooks.nix.";
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
      map (name: lib.mkIf (active name && cfg.package != null) { home.file = filesFor name; }) managed
    ))
    (lib.mkIf (active "grok" && cfg.package != null) {
      home.file.".grok/hooks/herdr.json".source =
        pkgs.writers.writeJSON "herdr-grok-hooks.json" fragments.grok;
    })
    (lib.optionalAttrs claudeAvailable (
      lib.mkIf (active "claude") {
        programs.claude.settings.hooks = lib.zipAttrsWith (_: lib.concatLists) [
          typedClaudeHooks
          claudeHooks
        ];
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
        programs.antigravity-cli.nativeHooks = fragments.antigravity-cli;
      }
    ))
    (lib.optionalAttrs codexAvailable (
      lib.mkIf (active "codex") {
        programs.codex.hooks.events = fragments.codex.hooks;
      }
    ))
  ];
}
