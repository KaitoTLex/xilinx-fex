# The external (non-Xilinx) libraries Vivado needs, as real x86_64 binaries.
#
# Vivado ships ~175 of its own libs under lib/lnx64.o; only ~17 are expected
# from the system. box64 substitutes its own native aarch64 wrappers for these,
# but qemu-user needs genuine x86_64 .so files — including the x86_64 dynamic
# loader, which it finds via QEMU_LD_PREFIX pointing at $out (hence the lib64
# symlink).
#
# Everything here is fetched prebuilt from cache.nixos.org for x86_64-linux;
# symlinkJoin itself runs on the aarch64 host, so nothing is cross-compiled or
# emulated at build time.
{
  lib,
  path,
  symlinkJoin,
}:

let
  x86 = import path {
    system = "x86_64-linux";
    config = { };
    overlays = [ ];
  };
in
symlinkJoin {
  name = "vivado-x86_64-libs";

  paths = with x86; [
    # core runtime
    glibc # libc/libm/libpthread/librt/libdl/libutil + ld-linux-x86-64.so.2
    stdenv.cc.cc.lib # libstdc++.so.6, libgcc_s.so.1, libquadmath.so.0
    libuuid.lib # libuuid.so.1
    util-linux.lib # libblkid.so.1, libmount.so.1
    elfutils.out # libelf.so.1, libdw.so.1
    zlib
    zstd.out # libzstd.so.1
    libxcrypt-legacy # libcrypt.so.1
    libffi
    pcre2
    expat
    libunwind
    libcap.lib
    ncurses # libtinfo.so.6
    ncurses5 # libncurses.so.5, libncursesw.so.5, libpanelw.so.5, libtinfo.so.5
    libtirpc
    libnsl
    libyaml
    onetbb # libtbb.so.12 (Vivado ships its own libtbb.so.2)

    # X11
    libx11
    libxext
    libxrender
    libxft
    libxi
    libxtst
    libxfixes
    libxcomposite
    libxdamage
    libxrandr
    libxcursor
    libxinerama
    libxxf86vm
    libxcb
    xcbutilwm
    libxau
    libxdmcp
    libxshmfence
    libxkbcommon

    # GTK / GLib stack (Vivado's dialogs and file choosers)
    glib.out
    gtk2
    gtk3
    gdk-pixbuf
    pango.out
    cairo
    atk
    at-spi2-atk
    at-spi2-core
    harfbuzz
    pixman
    freetype
    fontconfig.lib
    libpng
    libjpeg.out
    libtiff.out

    # rendering
    libglvnd # libGL.so.1
    mesa
    libepoxy
    libdrm
    libgbm
    wayland

    # networking / crypto (license checking, TCL http, docs)
    curl.out
    openssl.out
    dbus.lib
    gnutls.out
    nettle
    libtasn1
    libidn2.out
    libunistring
    krb5.lib # libkrb5, libk5crypto, libgssapi_krb5, libcom_err
    nss
    nspr
    libgcrypt
    libgpg-error

    # misc device/IO
    alsa-lib
    cups.lib
  ];

  # Both emulators resolve a guest ELF's interpreter path (/lib64/ld-linux-x86-64.so.2)
  # relative to this directory. It must be a REAL file: symlinkJoin would leave a
  # symlink pointing at an absolute /nix/store path, which FEX cannot follow through
  # its rootfs -- it fails with "Invalid or Unsupported elf file ... misconfigured
  # x86-64 RootFS". (nixpkgs' own x86_64 binaries hide this, because they embed an
  # absolute /nix/store interpreter path and never consult the rootfs at all.)
  postBuild = ''
    real=$(readlink -f "$out/lib/ld-linux-x86-64.so.2")
    for d in lib lib64; do
      mkdir -p "$out/$d"
      # if lib64 is itself a symlink to lib, the first pass already fixed it
      if [ ! -e "$out/$d/ld-linux-x86-64.so.2" ] || [ -L "$out/$d/ld-linux-x86-64.so.2" ]; then
        rm -f "$out/$d/ld-linux-x86-64.so.2"
        cp "$real" "$out/$d/ld-linux-x86-64.so.2"
        chmod +x "$out/$d/ld-linux-x86-64.so.2"
      fi
    done
  '';

  meta = {
    description = "x86_64 system libraries + loader for running Xilinx tools under qemu-user";
    platforms = [ "aarch64-linux" ];
  };
}
