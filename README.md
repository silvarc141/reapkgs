>[!WARNING]
>Unstable software, attribute names and options are subject to change

# reapkgs

## What it is

reapkgs is a set of tools for the Nix ecosystem that repackages [ReaPack](https://reapack.com) repos. Allows declarative configuration of ReaPack packages included in a nix-managed installation of [REAPER](https://www.reaper.fm) (for example using [home-manager](https://github.com/nix-community/home-manager)).

## What it is not

reapkgs is NOT meant to replace ReaPack itself. The project supports only a small subset of ReaPack's functionality and is meant to be used alongside it. For example, this is usable only in nix-enabled environments and there are no plans for package discovery tools. That said, reapkgs does not require installation or usage of ReaPack.

## How to use (TODO)

A flake for ReaPack repos deemed as ['known'](https://reapack.com/repos.txt) by ReaPack itself exists in the [reapkgs-known](https://github.com/silvarc141/reapkgs-known) repo.  

## Package discovery

Simplest way to find a reapkgs package exact attribute name is to search the generated JSON files.
As of now there are no plans for other means of package discovery.

## Made possible thanks to:

- [REAPER by Cockos, Inc](https://www.reaper.fm)
- [ReaPack by cfillion](https://github.com/cfillion/reapack)
- [firefox-addons by rycee](https://gitlab.com/rycee/nur-expressions/-/blob/master/pkgs/firefox-addons)
