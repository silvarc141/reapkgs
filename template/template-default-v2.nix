{
  lib,
  mkReapackPackage,
  stdenv,
  fetchurl,
}: let
  importedSet = builtins.fromJSON (builtins.readFile ./test.json)
  # importedPackages = map (path: import path {inherit lib mkReapackPackage stdenv fetchurl;}) imports;
in
  lib.foldl lib.mergeAttrs {} importedPackages
