{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.1.22";

  # Nix system -> release target. Hashes are the sha256 values in
  # https://releases.herdr.dev/core/<version>/manifest.json, in SRI form.
  targets = {
    aarch64-darwin = {
      name = "macos-aarch64";
      hash = "sha256-kHmNqt76jRJrkO8Lzb6cfdqcbPvwEaJHBlq12jSPNQ4=";
    };
    aarch64-linux = {
      name = "linux-aarch64";
      hash = "sha256-mHV5hSRdRfjXPdheaLE5t/FnwoSIu4nt2YNMP1pc9M8=";
    };
    x86_64-linux = {
      name = "linux-x86_64";
      hash = "sha256-MFTsOZLOgMVxXXIcqp3O+mBWch0V3BE/R1CvznY7pd8=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;
  target = targets.${system} or (throw "herdr-core: no release build for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "herdr-core";
  inherit version;

  src = fetchurl {
    url = "https://releases.herdr.dev/core/${version}/herdr-core-${target.name}.tar.gz";
    inherit (target) hash;
  };

  sourceRoot = ".";
  # The macOS executables carry the vendor's Developer ID signature; fixup must not touch them.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    if [ -d "Herdr Core.app" ]; then
      mkdir -p "$out/Applications"
      cp -R "Herdr Core.app" "$out/Applications/"
      # Upstream's entry points also link into the bundle, so macOS privacy prompts name Herdr Core.
      ln -s "../Applications/Herdr Core.app/Contents/MacOS/herdr-core" "$out/bin/herdr-core"
    else
      install -Dm755 herdr-core "$out/bin/herdr-core"
    fi
    ln -s herdr-core "$out/bin/hc"
    install -Dm644 LICENSE "$out/share/licenses/herdr-core/LICENSE"
    runHook postInstall
  '';

  meta = {
    description = "Terminal core that Herdr clients, including the mobile app, reach over SSH";
    homepage = "https://github.com/herdrdev/herdr-core";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames targets;
    mainProgram = "hc";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
