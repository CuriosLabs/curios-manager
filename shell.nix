{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    # For pkgs/curios-manager/
    btop
    curl
    duf
    efitools
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
    nix-search-cli
    nixos-option
    pamtester
    #nvtopPackages.full
    restic
    sbctl
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

