{ pkgs, lib, config, ... }:

{
  # This project's own additions. The shared .NET and SQL Server setup --
  # both SDKs, the C# Dev Kit fix, sqlcmd and the `devenv up` container,
  # run-tests, update-shared, update-toolchain -- comes from
  # devenv-templates/modules/{dotnet,mssql}, imported in devenv.yaml. Anything
  # here is added on top of it; a shared value is overridden with lib.mkForce.
  #
  #   packages = [ pkgs.nodejs ];
  #   env.ConnectionStrings__Default = "Server=127.0.0.1,1433;...";
}
