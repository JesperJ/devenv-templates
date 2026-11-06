# For `devenvify --personal dotnet`: the shared setup for a repo that carries
# no devenv files of its own (a customer's or an open-source repo). Bound per
# machine with `devenv --from ... allow`; nothing is written into that repo.
#
# The same parts as ../../dotnet/devenv.yaml. They are joined with Nix imports
# here, not devenv.yaml `imports:`, because devenv refuses yaml imports that
# reach outside the folder --from points at.
{
  imports = [
    ../../modules/dotnet/devenv.nix
    ../../modules/dotnet-runtime-8/devenv.nix
  ];
}
