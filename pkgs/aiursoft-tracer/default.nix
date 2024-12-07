{ lib
, pkgs
, buildDotnetModule
, dotnetCorePackages
, buildNpmPackage
, fetchFromGitHub
, ...
}:

let
  pname = "aiursoft-tracer";
  src = fetchFromGitHub {
    owner = "AiursoftWeb";
    repo = "Tracer";
    rev = "a72a35d733b15bd85bb72341b36483cfd185bb73";
    hash = "sha256-cDdEbaZb936rkkVZ7GPGQwSgGAT52Dxyic/ipP7BhbM=";
  };

  version = "1.0.0-${builtins.substring 0 7 src.rev}";

  wwwroot = buildNpmPackage {
    pname = "${pname}-wwwroot";
    src = "${src}/src/wwwroot";
    inherit version;
    npmDepsHash = "sha256-6gfwlUqi0coQ4qoQyw3M1cPWTCjtbWyhl7wtVdhvGKc=";
    dontNpmBuild = true;

    installPhase = ''
      mkdir -p $out
      cp -r * $out
    '';
  };
in
buildDotnetModule {
  inherit pname src version wwwroot;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_8_0;
  nugetDeps = ./deps.nix;

  nativeBuildInputs = with pkgs; [ patchelf ];

  projectFile = "Aiursoft.Tracer.sln";

  postFixup = ''
    # Symlink wwwroot
    rm -rf $out/lib/${pname}/wwwroot
    mkdir -p $out/assets
    ln -s ${wwwroot} $out/assets/wwwroot

    # Patch working directory
    dir=$out/assets
    sedexpr='s/\(exec.*Aiursoft\.Tracer.*\)/(cd '
    sedexpr+=''${dir//\//\\/}
    sedexpr+=' \&\& \1)/g'
    sed -i -e "$sedexpr" $out/bin/Aiursoft.Tracer
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    homepage = "https://tracer.aiursoft.cn";
    description = "Tracer is a simple network speed test app.";
    license = licenses.mit;
    mainProgram = "Aiursoft.Tracer";
  };
}
