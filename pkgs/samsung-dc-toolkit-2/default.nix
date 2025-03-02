{
  stdenv,
  fetchurl,
  samsung-dc-toolkit-3,
}:

samsung-dc-toolkit-3.overrideAttrs (old: rec {
  version = "2.1";

  src = fetchurl {
    url = "https://download.semiconductor.samsung.com/resources/software-resources/Samsung_SSD_DC_Toolkit_for_Linux_V${version}";
    hash = "sha256-mkz16/Rta3PK59e0gG1s/+rnxHFl/fLtkaZT2xIGR/A=";
  };

  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ${src} $out/bin/Samsung_SSD_DC_Toolkit_V${version}
    chmod +x $out/bin/Samsung_SSD_DC_Toolkit_V${version}

    runHook postInstall
  '';

  meta.mainProgram = "Samsung_SSD_DC_Toolkit_V${version}";
})
