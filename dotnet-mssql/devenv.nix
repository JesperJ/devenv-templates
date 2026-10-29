{ pkgs, lib, config, ... }:

let
  # Per-repo name for the SQL Server container and volume, so two repos never share
  # a database. Taken from the project folder, so this file works unchanged whether
  # it is copied in by devenvify or imported from devenv-templates.
  name = lib.toLower (baseNameOf config.devenv.root);
in
{
  packages = [
    pkgs.sqlcmd
  ];

  env = {
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_NOLOGO = "1";
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

  # Both SDKs on one `dotnet`; global.json in the repo picks which one builds.
  # .NET 8 runtimes come with its SDK, so net8.0 projects also run and test.
  languages.dotnet = {
    enable = true;
    package = with pkgs.dotnetCorePackages; combinePackages [
      sdk_10_0
      sdk_8_0
    ];
  };

  scripts = {
    # Picks up the single .sln/.slnx in the repo root.
    run-tests.exec = ''
      cd "$DEVENV_ROOT"
      dotnet test "$@"
    '';

    # Update the pinned toolchain and check the solution still tests green on it.
    # `devenv update` only rewrites devenv.lock - this shell keeps the old SDK on
    # PATH - so the tests have to run in a fresh `devenv shell`.
    update-toolchain.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"

      devenv update
      if ! devenv shell -- run-tests; then
        echo "FAILED on the new toolchain - 'git checkout devenv.lock' to revert" >&2
        exit 1
      fi
      git --no-pager diff --stat devenv.lock
    '';
  };

  enterShell = ''
    echo "${name} dev env"
    echo "  dotnet SDKs: $(dotnet --list-sdks | cut -d' ' -f1 | paste -sd' ')"
    echo "  devenv up (SQL Server), run-tests, update-toolchain"
  '';
}
