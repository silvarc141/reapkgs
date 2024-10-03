>[!Warning]
>Unstable software, attribute names are subject to change

# reapkgs

## What it is

reapkgs is a nix flake repackaging of [ReaPack](https://reapack.com) repos. Allows declarative configuration of ReaPack packages included in a nix-managed installation of [REAPER](https://www.reaper.fm) (for example using [home-manager](https://github.com/nix-community/home-manager)).

## What it is not

reapkgs is NOT meant to replace ReaPack itself. The project supports only a small subset of ReaPack's functionality, and is meant to be used alongside it. For example, there is no plans for package discovery through reapkgs, or use outside of nix-enabled environments. That said, reapkgs does not require installation or usage of ReaPack.

## How to use

TODO

## Made possible thanks to:

- [REAPER by Cockos, Inc](https://www.reaper.fm)
- [ReaPack by cfillion](https://github.com/cfillion/reapack)
- [firefox-addons by rycee](https://gitlab.com/rycee/nur-expressions/-/blob/master/pkgs/firefox-addons)
