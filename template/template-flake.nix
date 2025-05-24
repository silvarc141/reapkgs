{
  description = ''
    A reapkgs flake generated from the following Reapack indexes:
    #insert index-urls

    Links:
    Main repo: https://github.com/silvarc141/reapkgs
    Flake generated for known ReaPack repos: https://github.com/silvarc141/reapkgs-known
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
          inherit (pkgs) lib fetchurl stdenv;
        };
    });
}
