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
  }: let
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

    mkReaPackIndex = {
      pkgs,
      jsonPath,
    }: let
      entries = builtins.fromJSON (builtins.readFile jsonPath);
      buildEntry = name: entry:
        mkReaPackPackage {
          inherit pkgs name entry;
        };
    in
      pkgs.lib.mapAttrs buildEntry entries;
  in
    {
      lib = {
        inherit mkReaPackPackage mkReaPackIndex;
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      utils = nix-utils.legacyPackages.${system};
      pkgs = nixpkgs.legacyPackages.${system};

      generate-reapkgs-no-deps = utils.writeNuScriptBin "generate-reapkgs" (builtins.readFile ./generate-reapkgs.nu);

      generate-reapkgs = pkgs.writeShellApplication {
        name = "generate-reapkgs";
        runtimeInputs = [
          pkgs.curl
          pkgs.nix
        ];
        text = ''${pkgs.lib.getExe generate-reapkgs-no-deps} "$@"'';
      };
    in {
      formatter = pkgs.alejandra;
      packages.default = generate-reapkgs;
      legacyPackages = {inherit generate-reapkgs;};
    });
}
