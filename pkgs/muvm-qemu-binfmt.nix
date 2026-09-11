# Swaps muvm's x86-64 binfmt_misc entry from box64 to qemu-x86_64.
#
# Passed to `muvm -x`, so it runs as root inside the guest before the guest
# server starts. muvm registers box64 as BOX64 (x86-64) and BOX32 (i386); only
# the 64-bit entry is replaced, because box64 cannot load Vivado — it dies
# relocating libxv_isl_iostreams.so with "Symbol m not found, cannot apply
# R_X86_64_JUMP_SLOT" (reproduced on box64 0.4.2 and 0.4.4, at 16 KB and 4 KB
# pages, with/without dynarec, and across BOX64_MMAP32 / BOX64_MALLOC_HACK /
# BOX64_EMULATED_LIBS). BOX32 is left alone so box64 still covers 32-bit x86.
#
# binfmt_misc parses the \xNN sequences itself, so they must reach the kernel as
# literal text: use printf '%s' and never printf '\x..', which would expand them
# into raw bytes (and truncate the string at the first NUL).
{
  writeShellScript,
  qemu,
}:

writeShellScript "muvm-register-qemu-x86_64" ''
  echo -1 > /proc/sys/fs/binfmt_misc/BOX64 2>/dev/null || true
  printf '%s\n' ':QEMU64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\x00\x00\x00\xff\xff\xff\xff\xff\xfe\xff\xff\xff:${qemu}/bin/qemu-x86_64:OCF' \
    > /proc/sys/fs/binfmt_misc/register
''
