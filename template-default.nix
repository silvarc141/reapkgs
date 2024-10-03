{
  mkReapackPackage,
  stdenv,
  fetchurl,
  lib,
}: let
  imports = [
    #insert imports
  ];
  importedPackages = map (path: import path {inherit mkReapackPackage stdenv fetchurl;}) imports;
in
  lib.foldl lib.mergeAttrs {} importedPackages
