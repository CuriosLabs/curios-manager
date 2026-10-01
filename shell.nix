{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    # For pkgs/curios-manager/
    btop
    duf
    efitools
    fastfetch
    fd
    fwupd
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
    rsync
    sbctl
    smartmontools
    terminaltexteffects
    # For justfile
    statix
    shellcheck
    fd
    just
    git
  ];
}

