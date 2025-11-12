{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./pkgs/curios-manager {}

# test it locally with:
# nix-build && nix-env -i -f default.nix
# See:
#nix profile list
#nix-env --uninstall curios-manager
