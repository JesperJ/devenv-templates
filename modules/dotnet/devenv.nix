# The shared .NET setup: the SDK, the environment every .NET process here
# needs, and the project scripts. Other parts add to it -- dotnet-runtime-8
# puts the .NET 8 runtime next to the SDK -- and a project's own devenv.nix
# adds on top, or overrides a value with lib.mkForce.
#
# How a project gets this (devenvify --shared, --copy or --personal) decides
# who owns it; see the README.
{ pkgs, lib, config, ... }:

let
  # Project name for the shell banner, taken from the project folder.
  name = lib.toLower (baseNameOf config.devenv.root);

  # For the update scripts. The lock is kept before an update, so it can be
  # put back -- with --personal it is not in git, so `git checkout` cannot.
  keepLock = ''
    mkdir -p .devenv && cp devenv.lock .devenv/devenv.lock.before
  '';
  showLock = ''
    if git ls-files --error-unmatch devenv.lock >/dev/null 2>&1; then
      git --no-pager diff --stat devenv.lock
    else
      echo "devenv.lock updated (kept on this machine, not in git)"
    fi
  '';
in
{
  # How the parts join: each adds the runtimes it brings to this list, and
  # they all end up on the one `dotnet` below. Plumbing between parts, not a
  # setting -- a project picks runtimes by which parts it imports.
  options.shared.dotnet.runtimes = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    internal = true;
    description = "Runtimes the imported parts put next to the SDK.";
  };

  config = {
    env = {
      DOTNET_CLI_TELEMETRY_OPTOUT = "1";
      DOTNET_NOLOGO = "1";

      # Hand nix-ld THIS project's glibc instead of the machine's.
      #
      # Some of what .NET starts is not a Nix-built program but an unpatched
      # Microsoft binary, which on a NixOS machine runs through nix-ld:
      #
      #   - the launcher `dotnet run` builds and starts (bin/Debug/.../MyApp)
      #   - the VS Code C# Dev Kit's own host, Microsoft.VisualStudio.Code.ServiceHost
      #
      # nix-ld starts them with the MACHINE's glibc, and they then load
      # libcoreclr.so out of this project's SDK or runtime, which was built
      # against THIS project's glibc. If the machine's is older, they die
      # before running any code:
      #
      #   Failed to load .../libcoreclr.so, error:
      #   /nix/store/...-glibc-2.42-.../lib/libm.so.6:
      #   version `GLIBC_2.44' not found
      #   Failed to create CoreCLR, HRESULT: 0x80008088
      #
      # Seen with the Dev Kit (2026-11-02) and with `dotnet run` of a net8.0
      # app (2026-11-06), both on a machine with glibc 2.42 while
      # devenv-nixpkgs/rolling had 2.44. `dotnet build` and `dotnet test` are
      # unaffected: they run the Nix-built `dotnet` itself.
      #
      # Set here, the project carries its own glibc, so it does not matter how
      # old the machine is and devenv.yaml can keep tracking `rolling`. VS Code
      # gets these only if it loads this environment, which is what the
      # mkhl.direnv extension in .vscode/extensions.json is for.
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
    };

    # The SDK first: combinePackages takes the `dotnet` command from the first
    # package. SDK 10 builds for net8.0 too; running and testing a net8.0
    # project also needs the .NET 8 runtime, from the dotnet-runtime-8 part.
    languages.dotnet = {
      enable = true;
      package = pkgs.dotnetCorePackages.combinePackages (
        [ pkgs.dotnetCorePackages.sdk_10_0 ] ++ config.shared.dotnet.runtimes
      );
    };

    scripts = {
      # Picks up the single .sln/.slnx in the repo root.
      run-tests.exec = ''
        cd "$DEVENV_ROOT"
        dotnet test "$@"
      '';

      # Take the latest shared setup from devenv-templates -- this file, and
      # the other shared parts -- and check the solution still tests green on
      # it. Only that one input moves; the SDK moves with update-toolchain.
      update-shared.exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"

        # --shared and --personal lock devenv-templates; --copy has its own
        # copy of the parts and no such input.
        if ! grep -qs '"devenv-templates"' devenv.lock; then
          echo "This repo has its own copy of the shared setup, in .shared-devenv/ (devenvify --copy)."
          echo "Nothing to pull: edit it there, or take the current one with 'devenvify --copy <template> -f'."
          exit 0
        fi

        ${keepLock}
        devenv update devenv-templates
        if ! devenv shell -- run-tests; then
          echo "FAILED on the new shared setup - to go back: cp .devenv/devenv.lock.before devenv.lock" >&2
          exit 1
        fi
        ${showLock}
      '';

      # Update everything pinned -- the SDK, nixpkgs, the shared setup -- and
      # check the solution still tests green on it. `devenv update` only
      # rewrites devenv.lock - this shell keeps the old SDK on PATH - so the
      # tests have to run in a fresh `devenv shell`.
      update-toolchain.exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"

        ${keepLock}
        devenv update
        if ! devenv shell -- run-tests; then
          echo "FAILED on the new toolchain - to go back: cp .devenv/devenv.lock.before devenv.lock" >&2
          exit 1
        fi
        ${showLock}
      '';
    };

    enterShell = ''
      echo "${name} dev env"
      echo "  dotnet SDK: $(dotnet --list-sdks | cut -d' ' -f1 | paste -sd' ')"
      echo "  runtimes:   $(dotnet --list-runtimes | grep '^Microsoft.NETCore.App ' | cut -d' ' -f2 | paste -sd' ')"
      echo "  run-tests, update-shared, update-toolchain"
    '';
  };
}
