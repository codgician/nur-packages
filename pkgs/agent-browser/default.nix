{
  lib,
  fetchFromGitHub,
  rustPlatform,
  nix-update-script,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "agent-browser";
  version = "0.25.3";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9wunuGSsxKqy9h3MMahW3hzZ+5iJrz/SotPRRGDu+kg=";
  };

  sourceRoot = "${finalAttrs.src.name}/cli";

  cargoHash = "sha256-vCxv2vKSWj5kIWhzWlbWNfEHrxnSg1i0nUBq6hWoQlM=";

  nativeCheckInputs = [ writableTmpDirAsHomeHook ];

  __darwinAllowLocalNetworking = true;

  # skills/ contains SKILL.md for tools like Claude Code
  postInstall = ''
    mkdir -p $out/share/agent-browser
    cp -r ../skills $out/share/agent-browser/
  '';

  passthru.updateScript = nix-update-script { };

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
