# For `devenvify --bind dotnet-mssql`: the shared .NET and SQL Server setup for
# a repo that carries no devenv files of its own. See ../dotnet/devenv.nix.
{
  imports = [
    ../../modules/dotnet/devenv.nix
    ../../modules/mssql/devenv.nix
  ];
}
