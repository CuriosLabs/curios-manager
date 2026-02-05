{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    # For pkgs/curios-manager/
    btop
    curl
    duf
    fastfetch
    fd
    fwupd
    gnutar
    gdu
    gum
    jq
    libnotify
    libsecret
    ncdu
    #nvtopPackages.full
    restic
    smartmontools
    terminaltexteffects
    wget
    # For justfile
    statix
    shellcheck
    fd
    just
    git
  ];
}

