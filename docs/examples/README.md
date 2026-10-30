# Examples

- [`templates/home-manager`](../../templates/home-manager/) is a complete Home
  Manager flake for `x86_64-linux`. Change the example user's home path and
  SSH alias to match the consumer's machine configuration.
- [`kimi-renderer.nix`](kimi-renderer.nix) shows the module fragment for an
  app-owned renderer. Import it beside the module that defines the referenced
  settings option; adapt `settingsPath` to that option.

The examples contain no credentials or consumer host inventory. Values stored
in Nix-generated files are visible in the Nix store and should not contain
secrets.

## External renderer paths

The seven `mkRendererModule` adapters use the applications' upstream default
HOME configuration directories. They do not discover runtime configuration
directory overrides.

| Integration | Default HOME directory |
| ----------- | ---------------------- |
| Devin       | `~/.config/devin`      |
| Droid       | `~/.factory`           |
| Kimi        | `~/.kimi-code`         |
| Hermes      | `~/.hermes`            |
| Qoder CLI   | `~/.qoder`             |
| Cursor      | `~/.cursor`            |
| MastraCode  | `~/.mastracode`        |

The app-owned renderer must provide the `settingsPath` option passed to
`mkRendererModule` and render its native config file. Use the listed default
directory when app settings refer to a Herdr hook file.

## Claude owner renderer

The Claude adapter expects the app-owned module to declare
`programs.claude.settings.hooks` as an attribute set of event names to lists
of hook records. The owner renderer must preserve its existing typed hooks
and concatenate Herdr's contributed hooks into each event list. A freeform
hooks setting that replaces the event lists is not compatible.
