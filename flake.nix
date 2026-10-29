{
  description = "devenv templates and devenvify";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          # The templates are bundled in the store, so devenvify works on machines
          # without this repo checked out. Set DEVENV_TEMPLATES_DIR to a checkout to
          # try template edits without rebuilding.
          devenvify = pkgs.writeShellApplication {
            name = "devenvify";
            runtimeInputs = with pkgs; [ coreutils findutils gnused gnugrep ];
            text = ''
              export DEVENV_TEMPLATES_DIR="''${DEVENV_TEMPLATES_DIR:-${self}}"
            '' + builtins.readFile ./devenvify;
          };
          default = devenvify;
        });

      # Same templates without the script: `nix flake init -t <this flake>#dotnet-mssql`
      # (plain copy - no .gitignore merge, no direnv allow).
      templates.dotnet-mssql = {
        path = ./dotnet-mssql;
        description = ".NET 10 + 8 with SQL Server in Docker";
      };
    };
}
