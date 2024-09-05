{ lib, sources, buildDotnetModule, dotnetCorePackages, ... }:

buildDotnetModule {
  inherit (sources.aiursoft-tracer) pname src;
  version = "1.0.0-${builtins.substring 0 7 sources.aiursoft-tracer.version}";

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;
  nugetDeps = ./deps.nix;

  projectFile = "Aiursoft.Tracer.sln";

  meta = with lib; {
    homepage = "https://tracer.aiursoft.cn";
    description = "Tracer is a simple network speed test app.";
    license = licenses.mit;
  };
}
