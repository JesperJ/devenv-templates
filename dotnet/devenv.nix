{ pkgs, lib, config, ... }:

let
  # Project name for the shell banner, taken from the project folder.
  name = lib.toLower (baseNameOf config.devenv.root);
in
{
  env = {
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_NOLOGO = "1";
  };

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
    echo "  run-tests, update-toolchain"
  '';
}
