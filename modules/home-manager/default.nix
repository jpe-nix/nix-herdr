{ inputs }:
{ ... }:
{
  _module.args.herdrClaudeCode = inputs.nix-claude-code;
  imports = [
    (import ./options.nix { inherit inputs; })
    ./settings.nix
    ./services.nix
    (import ./collie.nix { inherit inputs; })
    (import ./native-ui.nix { inherit inputs; })
    (import ./integrations.nix { inherit inputs; })
  ];
}
