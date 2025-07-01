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
            ${v.name} = mkReapackPackage lib stdenv fetchurl v.name p.relative_parent_directory v.files;
          }
        ) {} p.versions);
        versionDerivationsWithLatest = versionDerivations // {
          latest = mkReapackPackage lib stdenv fetchurl (lib.elemAt p.versions 0);
        };
      in versionDerivationsWithLatest;
    }
  ) {} importedSet;
in
  lazySet
