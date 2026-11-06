# For `devenvify --personal dotnet-mssql`: the parts of ../../dotnet-mssql for
# a repo that carries no devenv files of its own. See ../dotnet/devenv.nix.
{
  imports = [
    ../../modules/dotnet/devenv.nix
    ../../modules/dotnet-runtime-8/devenv.nix
    ../../modules/mssql/devenv.nix
  ];
}
