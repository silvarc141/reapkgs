{
  description = "reapkgs generation scripts";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-utils.url = "github:silvarc141/nix-utils";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    nix-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      utils = nix-utils.${system}.legacyPackages;
    in rec {
      formatter = nixpkgs.legacyPackages.${system}.alejandra;
      defaultPackage = self.packages.${system}.generate-reapkgs;
      packages = {
        generate-reapkgs = utils.writeNuScriptBin "generate-reapkgs" (builtins.readFile ./generate-reapkgs.nu);
      };
    });
}
