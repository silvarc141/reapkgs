{pkgs}: let
  scripts = [
    {
      name = "generateReapkgs";
      path = ./generate-reapkgs.sh;
      dependencies =
        (with pkgs; [xmlstarlet parallel])
        ++ map mkInclude [
          ./mk-reapack-package.nix
          ./template-flake.nix
          ./template-default.nix
        ];
    }
  ];

  mkInclude = path: (pkgs.writeTextFile {
    name = pkgs.lib.strings.sanitizeDerivationName (toString path);
    text = builtins.readFile path;
    destination = "/bin/${path}";
  });

  mkScript = elem: let
    inherit (elem) name;
    script = (pkgs.writeScriptBin name (builtins.readFile elem.path)).overrideAttrs (old: {
      buildCommand = ''
        ${old.buildCommand}
        patchShebangs $out
      '';
    });
  in {
    inherit name;
    value = pkgs.symlinkJoin {
      inherit name;
      paths = [script] ++ elem.dependencies;
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/${name} --prefix PATH : $out/bin
      '';
    };
  };
in
  builtins.listToAttrs (map mkScript scripts)
