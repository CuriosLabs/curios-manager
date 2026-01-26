{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell rec {
  nativeBuildInputs = with pkgs; [
    # For pkgs/curios-manager/
    libnotify
    gdu
    gum
  ];
}

