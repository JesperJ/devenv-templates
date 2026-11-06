{ pkgs, lib, config, ... }:

{
  # This project's own additions. The shared setup -- the .NET SDK and
  # runtimes, the nix-ld fix, run-tests, update-shared, update-toolchain --
  # comes from the parts listed under `imports:` in devenv.yaml. Anything here
  # is added on top of them; a shared value is overridden with lib.mkForce.
  #
  #   packages = [ pkgs.nodejs ];
  #   env.ASPNETCORE_ENVIRONMENT = "Development";
}
