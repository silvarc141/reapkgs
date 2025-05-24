{
  description = "reapkgs generation scripts";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in rec {
      formatter = nixpkgs.legacyPackages.${system}.alejandra;
      defaultPackage = packages.generateReapkgs;
      packages = import ./scripts.nix {inherit pkgs;};
    });
}
