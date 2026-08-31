{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  makeWrapper,
  runCommand,
  nurTests,
  systemd,
  libselinux,
  libcxx,
  minizip-ng,
  curl,
  libseccomp,
  libuuid,
  openssl,
  libcap,
  pcre2,
  acl,
  zlib,
  fuse,
  sqlite,
  glib,
  libffi,
  libmnl,
  libnetfilter_queue,
  libnfnetlink,
  coreutils,
  gnugrep,
  gzip,
}:

let
  pname = "mdatp";
  version = "101.26052.0011";
  ubuntuVersion = "26.04";
  architectures = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };
  hashes = {
    x86_64-linux = "sha256-Y1dlU2DS0F3OGzY9ytpYtfjfx3YbWghCyFMzlcgjP+Q=";
    aarch64-linux = "sha256-Y2gW4ox+TC72T+3l37Mij4YT9bZdJPAKc+vdX2gThbw=";
  };
  system = stdenv.hostPlatform.system;
  architecture = architectures.${system} or (throw "${pname}: unsupported system ${system}");
  runtimeLibraryPath = lib.makeLibraryPath [
    systemd
    libselinux
    libcxx
    minizip-ng
    curl
    libseccomp
    libuuid
    openssl
    stdenv.cc.cc.lib
    libcap
    pcre2
    acl
    zlib
    fuse
    sqlite
    glib
    libffi
    libmnl
    libnetfilter_queue
    libnfnetlink
  ];
  runtimeBinPath = lib.makeBinPath [
    coreutils
    gnugrep
    gzip
  ];
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchurl {
    url = "https://packages.microsoft.com/ubuntu/${ubuntuVersion}/prod/pool/main/m/mdatp/mdatp_${version}_${architecture}.deb";
    hash = hashes.${system};
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -a opt/microsoft/mdatp/sbin "$out/sbin"
    cp -a opt/microsoft/mdatp/lib "$out/lib"
    cp -a opt/microsoft/mdatp/conf "$out/conf"
    cp -a opt/microsoft/mdatp/resources "$out/resources"
    cp -a opt/microsoft/mdatp/definitions "$out/definitions"
    cp -a opt/microsoft/mdatp/ml_model "$out/ml_model"
    cp -a opt/microsoft/mdatp/tools "$out/tools"

    for executable in "$out"/sbin/*; do
      if [[ -f "$executable" && -x "$executable" && "$executable" != *.so ]]; then
        patchelf --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" "$executable"
        wrapProgram "$executable" \
          --prefix LD_LIBRARY_PATH : "$out/lib:${runtimeLibraryPath}" \
          --suffix PATH : "${runtimeBinPath}"
      fi
    done

    ln -s "$out/sbin/wdavdaemonclient" "$out/bin/mdatp"
    install -Dm444 opt/microsoft/mdatp/resources/mdatp_completion.bash \
      "$out/share/bash-completion/completions/mdatp"
    install -Dm444 opt/microsoft/mdatp/resources/mdatp_completion.zsh \
      "$out/share/zsh/site-functions/_mdatp"

    runHook postInstall
  '';

  # The vendor binaries require their bundled libraries and do not tolerate
  # the generic ELF fixup pass. Their interpreters and runtime paths are set
  # explicitly above instead.
  dontPatchELF = true;

  passthru = {
    # nix-update cannot discover Microsoft repository indexes, move between
    # Ubuntu repository versions, or update both architecture hashes together.
    updateScript = ./update.sh;
    tests.smoke = runCommand "${pname}-smoke" { nativeBuildInputs = [ gnugrep ]; } ''
      ${finalAttrs.finalPackage}/bin/mdatp help >output 2>&1 || true
      grep -Fq "Display all available options for this tool" output
      touch "$out"
    '';
    tests.mdatp = nurTests.mdatp;
  };

  meta = {
    description = "Microsoft Defender for Endpoint";
    homepage = "https://www.microsoft.com/en-us/security/business/endpoint-security/microsoft-defender-endpoint";
    changelog = "https://learn.microsoft.com/en-us/defender-endpoint/linux-whatsnew";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames architectures;
    maintainers = with lib.maintainers; [ codgician ];
    mainProgram = "mdatp";
  };
})
