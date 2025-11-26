{
  description = "reapkgs generation scripts";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      generate-reapkgs = pkgs.writeShellApplication {
        name = "generate-reapkgs";
        runtimeInputs = [
          pkgs.curl
          pkgs.nix
        ];
        text = let
          script = pkgs.writers.writeNuBin "generate-reapkgs" (builtins.readFile ./generate-reapkgs.nu);
        in ''${pkgs.lib.getExe script} "$@"'';
      };

      mkReaPackPackage = {
        name,
        entry,
        version ? "latest",
      }: let
        files = entry.${version} or (throw "Version '${version}' not found for '${name}'. Available: ${toString (builtins.attrNames entry)}");

        linkFarmEntries =
          builtins.map (file: {
            name = file.path;
            path = pkgs.fetchurl {
              inherit (file) url sha256;
            };
          })
          files;

        drv = pkgs.linkFarm (pkgs.lib.strings.sanitizeDerivationName name) linkFarmEntries;
      in
        drv
        // {
          inherit version;
          passthru = {
            version = version: mkReaPackPackage {inherit name entry version;};
          };
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
