# For `devenvify --bind dotnet`: the shared .NET setup for a repo that carries
# no devenv files of its own (a customer's or an open-source repo). Bound per
# machine with `devenv --from ... allow`; nothing is written into that repo.
{
  imports = [ ../../modules/dotnet/devenv.nix ];
}
