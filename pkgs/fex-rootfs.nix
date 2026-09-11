# Minimal x86-64 RootFS for FEX.
#
# FEX resolves a guest ELF's interpreter path (/lib64/ld-linux-x86-64.so.2)
# *inside* this directory, so the loader must be a REAL file here: a symlink
# pointing at an absolute /nix/store path cannot be followed through the rootfs
# and FEX bails with "Invalid or Unsupported elf file ... misconfigured x86-64
# RootFS". (nixpkgs' own x86_64 binaries hide this, because they embed an
# absolute /nix/store interpreter path and never consult the rootfs at all.)
#
# Deliberately *only* the loader. Everything else Vivado needs is reached by
# absolute path via LD_LIBRARY_PATH (see x86-libs.nix), which FEX passes
# straight through to the host filesystem. Pointing FEX_ROOTFS at the full
# ~130-package library farm instead makes it search that tree for every lookup
# and roughly triples startup time for no benefit.
{
  lib,
  runCommand,
  path,
}:

let
  x86 = import path {
    system = "x86_64-linux";
    config = { };
    overlays = [ ];
  };
in
runCommand "fex-x86_64-rootfs" { } ''
  mkdir -p $out/lib $out/lib64
  cp ${x86.glibc}/lib/ld-linux-x86-64.so.2 $out/lib64/ld-linux-x86-64.so.2
  cp ${x86.glibc}/lib/ld-linux-x86-64.so.2 $out/lib/ld-linux-x86-64.so.2
  chmod +x $out/lib64/ld-linux-x86-64.so.2 $out/lib/ld-linux-x86-64.so.2
''
