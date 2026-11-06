{
  description = "devenv templates and devenvify";

  # Thin wrapper around package.nix, for `nix run` and `nix flake init`.
  # Configs can skip the flake: `flake = false` input + callPackage package.nix.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      packages = forAllSystems (system: rec {
        devenvify = nixpkgs.legacyPackages.${system}.callPackage ./package.nix {
          rev = self.shortRev or self.dirtyShortRev or null;
        };
        default = devenvify;
      });

      # Same templates without the script: `nix flake init -t <this flake>#dotnet-mssql`
      # (plain copy - no .gitignore merge, no direnv allow).
      templates.dotnet = {
        path = ./dotnet;
        description = ".NET 10 SDK + .NET 8 runtime";
      };
      templates.dotnet-mssql = {
        path = ./dotnet-mssql;
        description = ".NET 10 SDK + .NET 8 runtime, with SQL Server in Docker";
      };
    };
}
