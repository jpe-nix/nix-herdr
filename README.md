# nix-herdr

Nix packages and modules for the
[Herdr](https://github.com/herdrdev/herdr) terminal workspace manager. The
Herdr TUI is the default; the native UI, Collie bridge, user services, and
agent integrations are opt-in.

Run the TUI without importing a Nix module:

```sh
nix run github:jpe-nix/nix-herdr
```

## Home Manager

Import the module into your Home Manager configuration with `inputs.nix-herdr`
available to the module. The module uses its pinned upstream Home Manager Herdr
implementation, including with Home Manager 26.05. This example adds a saved
SSH machine and enables the Pi integration; replace the example SSH alias with
an entry from your own OpenSSH configuration.

```nix
{ inputs, ... }:
{
  imports = [ inputs.nix-herdr.homeManagerModules.default ];

  programs.herdr = {
    enable = true;
    machines.example = {
      label = "Example machine";
      target = "herdr-example";
    };
    integrations.pi.enable = true;
  };
}
```

`programs.herdr.enable` defaults to `false`; enabling it installs the TUI and
writes its configuration. `programs.herdr.machines` defaults to `null`, which
leaves Herdr's saved-machine catalog unmanaged. Setting it to an attribute set
writes the declarative SSH catalog under the XDG state directory. Each entry
needs a `target` (an OpenSSH alias or SSH target). The label defaults to the
attribute name, the stable ID is derived from that name, the session defaults
to `default`, and `enabled` defaults to `true`. The TUI and native UI share the
catalog, while client selection state remains user-owned. Do not put SSH
credentials or private keys in Nix settings.

The TUI package is installed when `programs.herdr.enable` is true. Home Manager
owns `programs.herdr.settings` and its TOML renderer; empty settings leave the
configuration file unmanaged. `agentManifests` supplies TOML
agent-detection manifests. These values are serialized into the Nix store, so
they must contain no secrets. The complete Home Manager consumer flake is in
[`templates/home-manager`](templates/home-manager/).

## Optional components

- `programs.herdr.server.enable` defaults to `false`. In Home Manager it
  starts a per-user service on Linux or macOS. The NixOS module separately
  exposes `programs.herdr.enable`, `package`, and `server.enable` for a
  per-user systemd service.
- `programs.herdr.nativeUI.enable` defaults to `false`. Home Manager installs
  the native [herdr-gpui](https://github.com/penso/herdr-gpui) client on Linux;
  on macOS, import `darwinModules.default` and set the option at the
  nix-darwin system level, outside `home-manager.users`, to declare its
  Homebrew cask. Enabling the Home Manager option on macOS fails explicitly.
- `programs.herdr.collie.enable` defaults to `false`. It adds the
  [Collie](https://github.com/AltanS/collie) bridge and a user service for
  Collie's upstream phone/PWA client. Shared nonsecret settings are written to
  `~/.collie/config.toml`; the service-only `environment` option is not passed
  to ordinary CLI commands. Collie's instance configuration and `.env` can
  override shared settings and should be reconciled with them. Values in Nix
  must not contain secrets.
- Every `programs.herdr.integrations.<name>.enable` option defaults to `false`.

## Agent integrations

Ten integrations have built-in adapters: `pi`, `omp`, `claude`, `codex`,
`copilot`, `opencode`, `kilo`, `antigravity-cli`, `grok`, and `qwen`. The `pi`,
`omp`, `kilo`, and `grok` adapters install their bundled integration files.
The other six merge Herdr hooks through the application's native Home Manager
renderer; import and enable that application's module where required.

Seven additional integrations need an app-owned renderer: `devin`, `droid`,
`kimi`, `hermes`, `qodercli`, `cursor`, and `mastracode`. Import
`lib.integrations.mkRendererModule` alongside the module that owns the target
application's settings option. For example, when an app module provides
`programs.kimi.settings`:

```nix
{ inputs, ... }:
{
  imports = [
    (inputs.nix-herdr.lib.integrations.mkRendererModule {
      agent = "kimi";
      settingsPath = [ "programs" "kimi" "settings" ];
    })
  ];

  programs.herdr.integrations.kimi.enable = true;
}
```

The `settingsPath` must name an existing app-owned JSON, TOML, or YAML settings
option that merges list values. The factory adds Herdr's configuration
fragment to that option; the app module remains responsible for rendering its
own configuration file. These adapters use upstream default HOME directories
and do not follow runtime configuration-directory overrides. See the
[default paths](docs/examples/README.md#external-renderer-paths). Enabling one
of these seven integrations without its renderer fails module evaluation. No
integration runs an imperative installer or replaces a shared app
configuration file.

The Claude adapter also requires the app-owned renderer to declare
`programs.claude.hooks.events` as event-keyed lists of hook records. The owner
renderer combines these with the legacy `programs.claude.settings.hooks`.

## Flake outputs and systems

The flake exports `homeManagerModules.default` (also `homeModules.default`),
`nixosModules.default`, `darwinModules.default`, and `lib.integrations`.
Packages are `packages.herdr`, `packages.collie`, and `packages.default`;
`apps.default` runs the Herdr TUI.

Supported systems are `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.

## Validation

```sh
nix fmt
nix flake check
```

The flake checks cover generated Herdr configuration, default option values,
service definitions, and integration rendering/evaluation. The configuration
check runs the packaged `herdr config check` command against generated TOML.
These checks do not connect to an SSH machine or exercise a live TUI, native
UI, or Collie network session. CI runs the flake checks on each supported
architecture.

## Upstream projects

- Herdr TUI: [herdrdev/herdr](https://github.com/herdrdev/herdr)
- Herdr package: [Nixpkgs](https://github.com/NixOS/nixpkgs)
- Native UI: [penso/herdr-gpui](https://github.com/penso/herdr-gpui)
- Collie bridge: [AltanS/collie](https://github.com/AltanS/collie)

## License

MIT. See [LICENSE](LICENSE).
