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
      pkgs = nixpkgs.legacyPackages.${system};

      generate-reapkgs = pkgs.writeShellApplication {
        name = "generate-reapkgs";
        runtimeInputs = [
          pkgs.curl
          pkgs.nix
        ];
        text = let
          script = utils.writeNuScriptBin "generate-reapkgs" (builtins.readFile ./generate-reapkgs.nu);
        in ''${pkgs.lib.getExe script} "$@"'';
      };

      mkReaPackPackage = {
        name,
        entry,
        version ? "latest",
      }: let
        files = entry.${version} or (throw "Version '${version}' not found for '${name}'. Available: ${toString (builtins.attrNames entry)}");

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

          passthru = {version = version: mkReaPackPackage {inherit name entry version;};};

          installPhase = ''
            mkdir -p $out
            ${builtins.concatStringsSep "\n" installCommands}
          '';
        };

      mkReaPackIndex = jsonPath: let
        entries = builtins.fromJSON (builtins.readFile jsonPath);
        buildEntry = name: entry: mkReaPackPackage {inherit name entry;};
      in
        pkgs.lib.mapAttrs buildEntry entries;
    in {
      formatter = pkgs.alejandra;
      packages.default = generate-reapkgs;
      legacyPackages = {inherit generate-reapkgs;};
      lib = {
        inherit mkReaPackPackage mkReaPackIndex;
      };
    });
}
