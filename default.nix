{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./pkgs/curios-manager {}

# test it locally with `just build`.
