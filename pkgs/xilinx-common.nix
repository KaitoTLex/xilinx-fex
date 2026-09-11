# targetPkgs for buildFHSEnv: all packages are aarch64-native.
# box64 translates x86-64 library calls from Vivado to these ARM64 libraries.
# box86 handles any 32-bit x86 helper binaries bundled in the installer; on
# Apple Silicon (no AArch32 EL0) it only runs nested under qemu-arm — see
# pkgs/box86.nix for why plain box86 can't execute there at all.
pkgs: with pkgs; [
  box64
  (callPackage ./box86.nix { })

  bash
  coreutils
  util-linux
  toybox

  zlib
  ncurses5
  glib
  libxcrypt-legacy

  libX11
  libXext
  libXrender
  libXtst
  libXi
  libXft
  libxcb

  cairo
  pango
  harfbuzz
  fontconfig
  freetype
  pixman

  libdrm
  libgbm
  libpng
  libjpeg
  libtiff
  libwebp
  gdk-pixbuf

  gtk2
  gtk3
  at-spi2-atk

  libGL
  mesa
  vulkan-loader

  ocl-icd
  opencl-headers
  opencl-clhpp

  gcc
  gfortran
  stdenv.cc.cc.lib

  gitMinimal
  nettools
  unzip
  graphviz
  lsb-release
]
