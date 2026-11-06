{
  description = "devenv templates and devenvify";

  # Thin wrapper around package.nix, for `nix run` and `nix build`.
  # Configs can skip the flake: `flake = false` input + callPackage package.nix.
  # The templates are not offered for `nix flake init -t`: that would set a
  # project up without choosing a mode. devenvify is the way in.
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
    };
}
