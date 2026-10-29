# devenvify with the templates bundled in the store, so it works on machines
# without this repo checked out. Set DEVENV_TEMPLATES_DIR to a checkout to try
# template edits without rebuilding.
#
#   pkgs.callPackage ./package.nix { }
{
  writeShellApplication,
  coreutils,
  findutils,
  gnused,
  gnugrep,
}:
let
  # Only the template folders; the top-level files are this packaging.
  templates = builtins.path {
    name = "devenv-templates";
    path = ./.;
    filter =
      path: type:
      baseNameOf path != ".git" && (dirOf path != toString ./. || type == "directory");
  };
in
writeShellApplication {
  name = "devenvify";
  runtimeInputs = [
    coreutils
    findutils
    gnused
    gnugrep
  ];
  text = ''
    export DEVENV_TEMPLATES_DIR="''${DEVENV_TEMPLATES_DIR:-${templates}}"
  ''
  + builtins.readFile ./devenvify;
}
