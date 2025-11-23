{
  description = "reapkgs generation scripts";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-utils = {
      url = "github:silvarc141/nix-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    nix-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      utils = nix-utils.legacyPackages.${system};
      generate-reapkgs-package = utils.writeNuScriptBin "generate-reapkgs" (builtins.readFile ./generate-reapkgs.nu);
    in {
      formatter = nixpkgs.legacyPackages.${system}.alejandra;
      defaultPackage = generate-reapkgs-package;
      legacyPackages.${system} = {
        generate-reapkgs = generate-reapkgs-package;
      };
      lib = let 
        mkReaPackPackage = {
          pkgs,
          name,
          entry,
          version ? "latest",
        }: let
          files = entry.${version};

          installFile = file: let
            source = pkgs.fetchurl {
              inherit (file) url sha256;
            };
            target = "$out/${file.path}";
          in ''
            mkdir -p "$(dirname "${target}")"
            ln -s "${source}" "${target}"
          '';

          installCommands = builtins.map installFile files;
        in
          pkgs.stdenv.mkDerivation {
            name = pkgs.lib.strings.sanitizeDerivationName name;
            inherit version;

            dontUnpack = true;

            installPhase = ''
              mkdir -p $out
              ${builtins.concatStringsSep "\n" installCommands}
            '';
          };
      in {
        inherit mkReaPackPackage;
        mkReaPackIndex = { pkgs, jsonPath }:
          let
            entries = builtins.fromJSON (builtins.readFile jsonPath);

            buildEntry = name: entry: mkReaPackPackage {
              inherit pkgs name entry;
            };
          in
            pkgs.lib.mapAttrs buildEntry entries;
      };
    });
}
