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

    # Hand nix-ld THIS project's glibc instead of the host's.
    #
    # Needed because the VS Code C# Dev Kit's own host,
    # Microsoft.VisualStudio.Code.ServiceHost, is an unpatched Microsoft
    # binary. On a NixOS/nix-ld machine that binary is started with the
    # SYSTEM's library set, and it then dlopens libcoreclr.so out of the SDK
    # below. libm.so.6 is already resident by SONAME at that point, so the
    # dlopen is stuck with whichever glibc the system supplied -- one process,
    # two glibcs. If the system's is older than this project's, the Dev Kit
    # dies before it loads a single file:
    #
    #   Failed to load .../dotnet-sdk-10.0.401/.../libcoreclr.so, error:
    #   /nix/store/...-glibc-2.42-84/lib/libm.so.6:
    #   version `GLIBC_2.44' not found
    #   Failed to create CoreCLR, HRESULT: 0x80008088
    #
    # Measured 2026-11-02 against a host on nixpkgs eaad0894 (glibc 2.42)
    # while devenv-nixpkgs/rolling was at 674a2028 (glibc 2.44). `dotnet
    # build` and `dotnet test` were fine throughout -- those are pure Nix
    # processes; only the unpatched Dev Kit host broke.
    #
    # Setting these makes the project self-contained, so it does not matter
    # how old the machine is and devenv.yaml can keep tracking `rolling`. The
    # same NIX_LD/NIX_LD_LIBRARY_PATH pair is what the NixOS wiki's DotNET
    # page uses for NativeAOT. It reaches VS Code only if the editor loads
    # this environment -- see .vscode/extensions.json for why mkhl.direnv is
    # recommended.
    NIX_LD = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2";
    NIX_LD_LIBRARY_PATH = lib.makeLibraryPath [
      pkgs.glibc
      pkgs.stdenv.cc.cc.lib   # libstdc++
      pkgs.icu                # .NET globalization
      pkgs.krb5               # Kerberos / integrated auth
      pkgs.openssl
      pkgs.zlib
      pkgs.libxml2
    ];
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
