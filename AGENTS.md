# Repository guidance

- Keep Herdr's TUI package and configuration as the default experience.
  Services, native UI, Collie, and agent integrations stay disabled unless a
  consumer enables them.
- Keep user settings, host details, and credentials consumer-owned. Values
  serialized into Nix store paths must not contain secrets.
- Agent adapters must use each application's native configuration renderer
  when one owns the shared configuration. Do not add imperative integration
  installers or overwrite application settings.
- Use the flake's `nix-devenv` formatting and lint profile. Do not add
  duplicate hook or lint configuration.
- Run `nix fmt` and `nix flake check` for changes to repository sources or
  examples. Keep generated outputs and machine-specific files out of the
  repository.
