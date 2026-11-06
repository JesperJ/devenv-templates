{ pkgs, lib, config, ... }:

{
  # This project's own additions. The shared .NET setup -- both SDKs, the
  # C# Dev Kit fix, run-tests, update-shared, update-toolchain -- comes from
  # devenv-templates/modules/dotnet, imported in devenv.yaml. Anything here is
  # added on top of it; a shared value is overridden with lib.mkForce.
  #
  #   packages = [ pkgs.nodejs ];
  #   env.ASPNETCORE_ENVIRONMENT = "Development";
}
