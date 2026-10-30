# Contributing

Keep changes focused and describe the consumer-visible behavior in the pull
request. Update the documentation when exported options, packages, module
paths, or supported systems change.

Use the formatting and lint tools provided by the flake profile; do not add a
separate hook or lint configuration. Before submitting a change, run:

```sh
nix fmt
nix flake check
```

Configuration and examples must not include personal host details,
credentials, or secret values. Prefer native Nix modules and application
renderers. Do not introduce imperative setup or activation scripts for
features represented by options.
