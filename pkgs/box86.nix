# box86 ships as an armv7l (32-bit ARM) binary — that's a hard requirement of its
# design, since it dlopens native 32-bit ARM .so's to "wrap" host libraries (GL,
# X11, GTK, ...) instead of fully emulating them.
#
# Apple Silicon cores have no AArch32 EL0: they cannot execute 32-bit ARM code
# natively at all, so the plain armv7l box86 binary fails outright on kanade
# with "exec format error" (verified directly from the store, no sandbox
# involved). QEMU's usermode armv7l emulator has no such dependency — it runs
# as an ordinary aarch64 process — so nesting box86 under `qemu-arm` recovers a
# working box86 on Apple Silicon: aarch64 host -> qemu-arm (-> armv7l) -> box86
# (-> x86/x86_64 target). Verified end-to-end: `box86 --version` runs box86's
# real startup path (arg parsing, config load, dynamic linking) correctly
# through this nesting.
#
# This is strictly a fallback for whatever 32-bit x86 helper binaries the
# Xilinx installer might bundle; Vivado/Vitis's own runtime is x86_64 and goes
# through box64 directly (see vivado-fhs.nix), so the extra translation layer
# here only matters for rare, install-time 32-bit code, not for Vivado itself.
{
  lib,
  box86,
  qemu,
  writeShellScriptBin,
}:
writeShellScriptBin "box86" ''
  exec ${lib.getExe' qemu "qemu-arm"} ${lib.getExe box86} "$@"
''
