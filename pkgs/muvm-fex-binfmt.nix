# Swaps muvm's x86-64 binfmt_misc entry from box64 to FEX.
#
# Passed to `muvm -x`, so it runs as root inside the guest before the guest
# server starts. FEX needs 4 KB pages, which is exactly what the muvm guest
# provides -- it cannot run on the 16 KB-page host at all.
#
# Why FEX over the alternatives, measured on `vivado -version` (full launcher
# chain, same machine, same guest):
#
#   qemu-x86_64   10.19s wall / 9.64s cpu
#   FEX            3.48s wall / 1.76s cpu
#
# box64 is not an option here regardless of speed: it cannot load Vivado at all
# (see muvm-qemu-binfmt.nix). Its BOX32 entry is left registered so 32-bit x86
# helpers still work.
#
# Flags are `F` (fix-binary) ONLY, and that matters:
#   * `C` (credentials) shifts the guest's argv, so Vivado saw argv[0] as
#     "-longversion" instead of "vivado" -- and its launcher picks which tool to
#     run from basename($0), so this silently runs the wrong thing.
#   * `O` (open-binary) passes an fd rather than a path, which mangles it too.
#   * `P` (preserve-argv0) breaks the guest outright.
#
# binfmt_misc parses the \xNN sequences itself, so they must reach the kernel as
# literal text: use printf '%s' and never printf '\x..', which would expand them
# into raw bytes (and truncate the string at the first NUL).
{
  writeShellScript,
  fex,
}:

writeShellScript "muvm-register-fex-x86_64" ''
  echo -1 > /proc/sys/fs/binfmt_misc/BOX64 2>/dev/null || true
  printf '%s\n' ':FEX64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\x00\x00\x00\xff\xff\xff\xff\xff\xfe\xff\xff\xff:${fex}/bin/FEX:F' \
    > /proc/sys/fs/binfmt_misc/register
''
