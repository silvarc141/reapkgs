>[!Warning]
>This README is outdated, from before nu rewrite

>[!Warning]
>Unstable software, attribute names and options are subject to change

# reapkgs

## What it is

reapkgs is a nix flake repackaging of [ReaPack](https://reapack.com) repos. Allows declarative configuration of ReaPack packages included in a nix-managed installation of [REAPER](https://www.reaper.fm) (for example using [home-manager](https://github.com/nix-community/home-manager)).

## What it is not

reapkgs is NOT meant to replace ReaPack itself. The project supports only a small subset of ReaPack's functionality, and is meant to be used alongside it. For example, this is usable only in nix-enabled environments and there are no plans right now for package discovery through reapkgs. That said, reapkgs does not require installation or usage of ReaPack.

## Generating flakes

A flake for "known" ReaPack repos is generated in the [reapkgs-known repo](https://github.com/silvarc141/reapkgs-known).  
If you only wish to use known repos, proceed to section about [using generated flakes](#using-generated-flakes).  
If you wish to use other ReaPack repos, you have to generate and include a new flake.

1. Create a file with urls to your repo's ReaPack index files.

(in urls.txt)
```
https://github.com/Yaunick/Yannick-ReaScripts/raw/master/index.xml
https://geraintluff.github.io/jsfx/index.xml
https://acendan.github.io/reascripts/index.xml
```
2. Generate the flake

### With nix package manager installed (recommended)

Run:
```
nix run github:silvarc141/reapkgs -- -gpri urls.txt
```

Or when on a non-flake-enabled system:
```
nix --experimental-features 'nix-command flakes' run github:silvarc141/reapkgs -- -gpri urls.txt
```

### Without nix installed

Install dependencies:
- XMLStarlet
- GNU Parallel

Clone repo, cd into it, then run:
./generate-reapkgs.sh -gpri urls.txt

### More info

For more info on the generator script run
```
nix run github:silvarc141/reapkgs -- -h
```
or without nix
```
./generate-reapkgs.sh -h
```

## Using generated flakes

1. Add to flake inputs

(in flake.nix)
```nix
{
  inputs = {
    # ...
    reapkgs-known.url = "github:silvarc141/reapkgs-known";
    reapkgs-known.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };
}
```
2. Use with home-manager

(in home.nix)
```nix
xdg.configFile.REAPER = {

  # join all packages in REAPER config path to preserve correct directory structure
  recursive = true;
  source = pkgs.symlinkJoin {
    name = "reapkgs";
    paths = with inputs.reapkgs-known.packages.${pkgs.system}; [

      # add packages
      reateam-extensions.reaper-oss-sws-ext-2-14-0-3
      (with saike-tools; [
        saike-yutani-jsfx-0-101
        squashman-jsfx-0-85
        saike-abyss-jsfx-0-05
      ])
    ];
  };
};
```

I plan on building a home-manager module for REAPER that will incorporate reapkgs in the future.

## Package discovery

Simplest way to find a reapkgs package exact attribute name is to search the generated flake after finding the name of the package in ReaPack browser.
As of now there are no plans for other means of package discovery.

Package names are generated from ReaPack package names, but adapted to a the nix package naming convention (lowercase-semicolon-separated).
Each ReaPack package version is a separate attribute in reapkgs, with its version sanitized and appended to the name.

## Made possible thanks to:

- [REAPER by Cockos, Inc](https://www.reaper.fm)
- [ReaPack by cfillion](https://github.com/cfillion/reapack)
- [firefox-addons by rycee](https://gitlab.com/rycee/nur-expressions/-/blob/master/pkgs/firefox-addons)
