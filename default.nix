{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./pkgs/curios-manager {}

# test it locally with:
# nix-build && nix profile add -f default.nix
# See:
#nix profile list
#nix profile remove curios-manager
