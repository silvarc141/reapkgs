{
  lib,
  mkReapackPackage,
  stdenv,
  fetchurl,
}: let
  importedSet = builtins.fromJSON (builtins.readFile ./test.json);
  lazySet = builtins.foldl' (packages: p:
    packages // {
      ${p.name} = let 
        versionDerivations = (builtins.foldl' (versions: v: 
          versions // {
            ${v.name} = mkReapackPackage ;
          }
        ) {} p.versions);
        versionDerivationsWithLatest = versionDerivations // {
          latest = mkReapackPackage ;
        };
      in versionDerivationsWithLatest;
    }
  ) {} importedSet;
  # importedPackages = map (path: import path {inherit lib mkReapackPackage stdenv fetchurl;}) imports;
in
  lazySet
