{
  description = "reapkgs generation scripts";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-utils = {
      url = "github:silvarc141/nix-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    nix-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      utils = nix-utils.legacyPackages.${system};
      generate-reapkgs-package = utils.writeNuScriptBin "generate-reapkgs" (builtins.readFile ./generate-reapkgs.nu);
    in {
      formatter = nixpkgs.legacyPackages.${system}.alejandra;
      defaultPackage = generate-reapkgs-package;
      legacyPackages.${system} = {
        generate-reapkgs = generate-reapkgs-package;
      };
    });
}
