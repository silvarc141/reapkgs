{
  description = ''
    A reapkgs flake generated from the following Reapack indexes:

    #insert index-urls

    Links:
    reapkgs main repo: https://github.com/silvarc141/reapkgs
    Known repos generated flake: https://github.com/silvarc141/reapkgs-known
  '';

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in rec {
      packages =
        {mkReapackPackage = import ./mk-reapack-package.nix;}
        // import ./reapack-packages {
          inherit (packages) mkReapackPackage;
          inherit (pkgs) fetchurl stdenv lib;
        };
    });
}
