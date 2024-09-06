{ lib, pkgs, sources, buildDotnetModule, dotnetCorePackages, buildNpmPackage, ... }:

let
  inherit (sources.aiursoft-tracer) pname src;
  version = "1.0.0-${builtins.substring 0 7 sources.aiursoft-tracer.version}";

  meta = with lib; {
    homepage = "https://tracer.aiursoft.cn";
    description = "Tracer is a simple network speed test app.";
    license = licenses.mit;
  };

  wwwroot = buildNpmPackage {
    pname = "${pname}-wwwroot";
    src = "${src}/src/wwwroot";
    inherit version meta;
    npmDepsHash = "sha256-6gfwlUqi0coQ4qoQyw3M1cPWTCjtbWyhl7wtVdhvGKc=";
    dontNpmBuild = true;

    installPhase = ''
      mkdir -p $out
      cp -r * $out
    '';
  };
in
buildDotnetModule {
  inherit pname src version meta wwwroot;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_8_0;
  nugetDeps = ./deps.nix;

  nativeBuildInputs = with pkgs; [ patchelf ];

  projectFile = "Aiursoft.Tracer.sln";

  postInstall = ''
    rm -rf $out/lib/${pname}/wwwroot
    ln -s ${wwwroot} $out/lib/${pname}/wwwroot
  '';

  # Patch working directory
  postFixup = ''
    dir=$out/lib/${pname}
    sedexpr='s/\(exec.*Aiursoft\.Tracer.*\)/(cd '
    sedexpr+=''${dir//\//\\/}
    sedexpr+=' \&\& \1)/g'
    sed -i -e "$sedexpr" $out/bin/Aiursoft.Tracer
  '';
}
