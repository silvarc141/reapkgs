{
  lib,
  stdenv,
  fetchurl,
  version,
  parentDirectory,
  files,
}:
let
  inherit (lib.strings) sanitizeDerivationName replaceStrings concatMapStrings;

  getPathFromSource = (s: if s.path == "" then (baseNameOf (decodeUrl s.url)) else s.path);

  sourcesWithName = map (s: s // {name = sanitizeDerivationName (decodeUrl s.url);}) sources;
in
  stdenv.mkDerivation {
    name = version;
    meta.platforms = lib.platforms.all;

    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;

    sourceRoot = ".";

    srcs = map (elem: fetchurl {inherit (elem) url sha256 name;}) sourcesWithName;

    pairs = escapeSingleQuote (concatMapStrings (s: "${s.name}|${(getPathFromSource s)}|") sourcesWithName);

    passAsFile = [ "srcs" "pairs" ];

    installPhase =
      #bash
      ''
        runHook preInstall

        dst="$out/${parentDirectory}"

        readarray -td '|' pairsArray < "$pairsPath"

        for ((i=0; i<''${#pairsArray[@]}; i+=2)); do
          name="''${pairsArray[i]}"
          path="''${pairsArray[i+1]}"
          targetName="$(basename "$path")"
          targetDir="$dst/$(dirname "$path")"

          if [ -f "$targetDir/$targetName" ]; then
            echo "File $targetDir/$targetName already exists. Skipping."
          else
            mkdir -p "$targetDir"
            readarray -td ' ' sourcesArray < $srcsPath
            source=""
            for src in ''${sourcesArray[@]}; do
              if [[ "$src" == *"$name" ]]; then
                source="$src"
                break
              fi
            done
            cp "$source" "$targetDir/$targetName"
          fi
        done

        runHook postInstall
      '';
  }
