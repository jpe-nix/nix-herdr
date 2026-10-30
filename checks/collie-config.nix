{
  inputs,
  pkgs,
  cfg,
  defaultConfig,
  homeDir,
  socket,
}:
let
  collieEnv =
    if pkgs.stdenv.hostPlatform.isDarwin then
      cfg.launchd.agents.collie.config.EnvironmentVariables
    else
      cfg.systemd.user.services.collie.Service.Environment;
  defaultCollieEnv =
    if pkgs.stdenv.hostPlatform.isDarwin then
      defaultConfig.launchd.agents.collie.config.EnvironmentVariables
    else
      defaultConfig.systemd.user.services.collie.Service.Environment;
  baseFile = defaultConfig.home.file.".collie/config.toml".source;
  overrideFile = cfg.home.file.".collie/config.toml".source;
in
assert builtins.hasAttr ".collie/config.toml" cfg.home.file;
assert
  if pkgs.stdenv.hostPlatform.isDarwin then
    !(defaultCollieEnv ? COLLIE_HOST)
    && !(defaultCollieEnv ? COLLIE_CONFIG)
    && !(defaultCollieEnv ? COLLIE_MUX)
  else
    !(builtins.any (
      value:
      builtins.any (prefix: pkgs.lib.hasPrefix prefix value) [
        "COLLIE_HOST="
        "COLLIE_CONFIG="
        "COLLIE_MUX="
      ]
    ) defaultCollieEnv);
assert
  if pkgs.stdenv.hostPlatform.isDarwin then
    builtins.elem "_exec-bridge" cfg.launchd.agents.collie.config.ProgramArguments
    && collieEnv.HERDR_SOCKET_PATH == socket
    && collieEnv.COLLIE_HOST == "127.0.0.3"
    && collieEnv.PATH == "/consumer/bin"
    && collieEnv.HOME == homeDir
    && collieEnv.COLLIE_CONFIG == "/consumer/config"
    && collieEnv.COLLIE_MUX == "consumer"
  else
    builtins.elem "${pkgs.lib.getExe pkgs.hello} _exec-bridge" cfg.systemd.user.services.collie.Service.ExecStart
    && builtins.elem "HERDR_SOCKET_PATH=${socket}" collieEnv
    && builtins.elem "COLLIE_HOST=127.0.0.3" collieEnv
    && builtins.elem "PATH=/consumer/bin" collieEnv
    && builtins.elem "HOME=${homeDir}" collieEnv
    && builtins.elem "COLLIE_CONFIG=/consumer/config" collieEnv
    && builtins.elem "COLLIE_MUX=consumer" collieEnv;
pkgs.runCommand "herdr-services" { nativeBuildInputs = [ pkgs.jq ]; } ''
  grep -F 'host = "127.0.0.2"' ${baseFile}
  grep -F 'mux = "herdr"' ${baseFile}
  grep -F 'mux = "tmux"' ${overrideFile}
  mkdir -p "$TMPDIR/home/.collie" "$TMPDIR/instance"
  ln -s ${baseFile} "$TMPDIR/home/.collie/config.toml"
  env -i HOME="$TMPDIR/home" PATH="${pkgs.coreutils}/bin" HERDR_PLUGIN_CONFIG_DIR="$TMPDIR/instance" \
    ${
      pkgs.lib.getExe inputs.collie-upstream.packages.${pkgs.stdenv.hostPlatform.system}.collie
    } config check
  env -i HOME="$TMPDIR/home" PATH="${pkgs.coreutils}/bin" HERDR_PLUGIN_CONFIG_DIR="$TMPDIR/instance" \
    ${
      pkgs.lib.getExe inputs.collie-upstream.packages.${pkgs.stdenv.hostPlatform.system}.collie
    } config show --json > "$TMPDIR/config.json"
  jq -e '
    any(.settings[]; .env == "COLLIE_MUX" and .value == "herdr" and .source == "file:home") and
    any(.settings[]; .env == "COLLIE_HOST" and .value == "127.0.0.2" and .source == "file:home") and
    (.problems | length == 0)
  ' "$TMPDIR/config.json" >/dev/null
  touch "$out"
''
