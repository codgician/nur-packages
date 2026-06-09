{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  rustPlatform,
  nodejs,
  pnpm_11,
  pnpmConfigHook,
  geist-font,
  nix-update-script,
  which,
  writableTmpDirAsHomeHook,
}:

let
  # Pin the pnpm major so the offline-store layout (and therefore
  # `pnpmDeps.hash`) is stable across nixpkgs bumps of the default `pnpm`
  # attribute. The upstream lockfile is `lockfileVersion: '9.0'`, which is
  # produced by pnpm 9/10/11; pinning to 11 keeps us aligned with what
  # contributors run locally.
  pnpm = pnpm_11;

  version = "0.27.1";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    tag = "v${version}";
    hash = "sha256-eLtN4ErLaSetEDb/6RMqILDnVua8QnEN6r1VgbwTQBw=";
  };

  # The Rust CLI embeds the dashboard UI via RustEmbed at compile time.
  # Build the Next.js static export so it can be placed at the expected path.
  dashboard = stdenv.mkDerivation {
    pname = "agent-browser-dashboard";
    inherit version src;

    nativeBuildInputs = [
      nodejs
      pnpm
      pnpmConfigHook
    ];

    __darwinAllowLocalNetworking = true;

    pnpmDeps = fetchPnpmDeps {
      pname = "agent-browser-dashboard";
      inherit version src pnpm;
      pnpmWorkspaces = [ "dashboard" ];
      fetcherVersion = 3;

      # The dashboard deps fetch OOM-kills (SIGKILL, exit 137) at the end of
      # `pnpm install` ("added 753, done") on the ~7 GB macos-latest CI runner
      # where atelier builds aarch64-darwin. The memory is in pnpm's worker
      # pool that writes the content-addressable store, so cap it to one worker
      # (PNPM_MAX_WORKERS for pnpm 11; PNPM_WORKERS=999, read by older pnpm as
      # "CPUs to leave idle", collapses the pool to one as a fallback) and cap
      # node's heap to force earlier GC. NODE_NO_WARNINGS drops the ~61k libuv
      # "unmanaged fd" warnings the store write emits. child/network-concurrency
      # bound the resolution phase. All are scheduling/memory/log knobs, so they
      # change how the store is written, not its contents: the fixed-output
      # `hash` below is unchanged (verified via `nix build --rebuild`) and Linux
      # consumers are unaffected.
      PNPM_MAX_WORKERS = "1";
      PNPM_WORKERS = "999";
      NODE_OPTIONS = "--max-old-space-size=2048";
      NODE_NO_WARNINGS = "1";
      prePnpmInstall = ''
        pnpm config set child-concurrency 1
        pnpm config set network-concurrency 1
      '';

      hash = "sha256-e7KlsuqS1YRcdQbKJwH9Dd6N28tYM3nPinJB5ZzSbp4=";
    };

    pnpmWorkspaces = [ "dashboard" ];

    # Replace Google Fonts fetch with a local font from nixpkgs since the
    # Nix sandbox has no network access.
    postPatch = ''
      substituteInPlace packages/dashboard/src/app/layout.tsx --replace-fail \
        '{ Geist } from "next/font/google"' \
        'localFont from "next/font/local"'

      substituteInPlace packages/dashboard/src/app/layout.tsx --replace-fail \
        'Geist({ subsets: ["latin"], variable: "--font-sans" })' \
        'localFont({ src: "./Geist-Regular.otf", variable: "--font-sans" })'

      cp "${geist-font}/share/fonts/opentype/Geist-Regular.otf" \
        packages/dashboard/src/app/Geist-Regular.otf
    '';

    buildPhase = ''
      runHook preBuild
      pnpm --filter dashboard build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r packages/dashboard/out $out
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "agent-browser";
  inherit version src;

  sourceRoot = "${finalAttrs.src.name}/cli";

  cargoHash = "sha256-tZtnCKhPFW9lpyj6JIEwYcEV1ZEXSCYlyxMkYi24Hqw=";

  # Place the pre-built dashboard where RustEmbed expects it
  postUnpack = ''
    chmod u+w source/packages/dashboard
    cp -r ${dashboard} source/packages/dashboard/out
  '';

  # `which_exists` spawns the external `which` binary at runtime to probe
  # for optional tools; pin it to an absolute store path.
  postPatch = ''
    substituteInPlace src/doctor/helpers.rs src/install.rs --replace-fail \
      '"which"' '"${lib.getExe which}"'
  '';

  nativeCheckInputs = [
    writableTmpDirAsHomeHook
  ];

  __darwinAllowLocalNetworking = true;

  # The `skills` subcommand looks for `skills/` and `skill-data/` next to
  # `bin/`, relative to the canonical exe path. See cli/src/skills.rs.
  postInstall = ''
    cp -r ../skills $out/skills
    cp -r ../skill-data $out/skill-data
  '';

  passthru = {
    inherit dashboard;
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "dashboard"
      ];
    };
  };

  meta = {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [ codgician ];
    mainProgram = "agent-browser";
  };
})
