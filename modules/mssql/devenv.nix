# SQL Server for local development, shared the same way as ../dotnet: projects
# import it, alongside the .NET module (see ../../dotnet-mssql/devenv.yaml).
{ pkgs, lib, config, ... }:

let
  # Per-repo name for the SQL Server container and volume, so two repos never
  # share a database. Taken from the project folder, so it is right in every
  # project that imports this.
  name = lib.toLower (baseNameOf config.devenv.root);
in
{
  packages = [
    pkgs.sqlcmd
  ];

  env = {
    # Local dev only - shared by the container below and `sqlcmd -S localhost -U sa`
    # (sqlcmd reads SQLCMDPASSWORD on its own).
    MSSQL_SA_PASSWORD = "Dev_Passw0rd!";
    SQLCMDPASSWORD = "Dev_Passw0rd!";
  };

  # SQL Server isn't in nixpkgs (Microsoft only ships images and .deb/.rpm), so
  # `devenv up` runs it in Docker. The named volume keeps the data across restarts;
  # `rm -f` clears a container left behind if the last run was killed. Only one repo
  # can hold port 1433 at a time - `devenv down` in the other one first.
  # From Windows (SSMS etc.) connect to `127.0.0.1,1433`, not `localhost` - Windows
  # resolves that to ::1, and WSL's IPv6 forwarding times out the SQL login.
  processes.mssql.exec = ''
    docker rm -f ${name}-mssql >/dev/null 2>&1 || true
    exec docker run --rm --name ${name}-mssql -p 1433:1433 \
      -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD \
      -v ${name}-mssql:/var/opt/mssql \
      mcr.microsoft.com/mssql/server:2022-latest
  '';

  # After the .NET module's banner, which starts with the project name.
  enterShell = lib.mkAfter ''
    echo "  devenv up: SQL Server on 127.0.0.1,1433"
  '';
}
