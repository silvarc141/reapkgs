{pkgs}: let
  scripts = [
    {
      name = "generateReapkgs";
      path = ./generate-reapkgs.sh;
      dependencies =
        (with pkgs; [xmlstarlet parallel])
        ++ map mkInclude [
          {name = "mk-reapack-package.nix"; path = ./mk-reapack-package.nix;}
          {name = "template-flake.nix"; path = ./template-flake.nix;}
          {name = "template-default.nix"; path = ./template-default.nix;}
        ];
    }
  ];
  mkInclude = {name, path}: (pkgs.writeTextFile {
    inherit name;
    text = builtins.readFile path;
    destination = "/bin/${name}";
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
      postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
    };
  };
in builtins.listToAttrs (map mkScript scripts)
