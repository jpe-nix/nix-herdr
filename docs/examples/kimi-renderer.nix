{ inputs, ... }:
{
  imports = [
    (inputs.nix-herdr.lib.integrations.mkRendererModule {
      agent = "kimi";
      settingsPath = [
        "programs"
        "kimi"
        "settings"
      ];
    })
  ];

  programs.herdr.integrations.kimi.enable = true;
}
