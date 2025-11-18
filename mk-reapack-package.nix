{
  lib,
  stdenv,
  fetchurl,
  name,
}: stdenv.mkDerivation {
    name = name;
    meta.platforms = lib.platforms.all;

    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;

    sourceRoot = ".";

    passAsFile = [ "srcs" "pairs" ];

    installPhase =
      #bash
      ''
        runHook preInstall

        dst="$out/${parentDir}"

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
