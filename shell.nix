{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell rec {
  nativeBuildInputs = with pkgs; [ pkg-config just ];

  buildInputs = with pkgs; [
    rustup
    cargo-c

    # Runtime dependencies which need to be in LD_LIBRARY_PATH
    wayland
    libxkbcommon
    vulkan-loader
    libGL

    # X11 fallback deps (often checked by winit)
    #xorg.libX11
    #xorg.libXcursor
    #xorg.libXi
    #xorg.libXrandr
  ];

  LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
}

