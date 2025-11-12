{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./pkgs/curios-manager {}

# test it locally with:
# nix-build && nix-env -i -f default.nix
