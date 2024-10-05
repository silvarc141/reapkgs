>[!Warning]
>Unstable software, attribute names and options are subject to change

# reapkgs

## What it is

reapkgs is a nix flake repackaging of [ReaPack](https://reapack.com) repos. Allows declarative configuration of ReaPack packages included in a nix-managed installation of [REAPER](https://www.reaper.fm) (for example using [home-manager](https://github.com/nix-community/home-manager)).

## What it is not

reapkgs is NOT meant to replace ReaPack itself. The project supports only a small subset of ReaPack's functionality, and is meant to be used alongside it. For example, there is no plans for package discovery through reapkgs, or use outside of nix-enabled environments. That said, reapkgs does not require installation or usage of ReaPack.

## Using generated flakes

1. Add to flake inputs
[in flake.nix]
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
[in home.nix]
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

## Generating flakes

A flake for "known" ReaPack repos is generated in the [reapkgs-known repo](https://github.com/silvarc141/reapkgs-known).
If you wish to use other ReaPack repos, you have to generate and include a new flake.

1. Create a file with urls to your repo's ReaPack index files.
[in urls.txt]
```
https://github.com/Yaunick/Yannick-ReaScripts/raw/master/index.xml
https://geraintluff.github.io/jsfx/index.xml
https://acendan.github.io/reascripts/index.xml
```
2. Generate the flake (nix installed, flakes enabled):
```
nix run github:silvarc141/reapkgs -- -gpri urls.txt
```

For more info on the generator script run
```
nix run github:silvarc141/reapkgs -- -h
```

## Made possible thanks to:

- [REAPER by Cockos, Inc](https://www.reaper.fm)
- [ReaPack by cfillion](https://github.com/cfillion/reapack)
- [firefox-addons by rycee](https://gitlab.com/rycee/nur-expressions/-/blob/master/pkgs/firefox-addons)
