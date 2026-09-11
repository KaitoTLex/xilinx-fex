# Xilinx Vivado on NixOS / Apple Silicon

Runs **Vivado / Vitis 2025.2 (x86-64) on aarch64 Apple Silicon** — verified working on an
M1 Pro (`vivado -version`, and a Tcl batch run that loads the full 504-part device
database). No x86 machine, no Rosetta, no full VM image.

```
nix run .#vivado          # or .#vitis / .#vitis_hls
```

## Why it takes three layers

Each layer solves exactly one problem. Skipping any one of them breaks it.

| Layer | Problem it solves |
|---|---|
| **muvm** (libkrun/KVM microVM) | Apple Silicon kernels use **16 KB pages**; x86-64 ELF segments are 4 KB aligned, so `qemu-user` cannot map them (`failed to map segment from shared object`). muvm boots a **4 KB-page** guest that shares the host filesystem. |
| **FEX or qemu-x86_64** via `binfmt_misc` | Translates x86-64 → aarch64 inside the guest (FEX requires 4 KB pages, which is why it must live inside muvm). muvm registers box64 as `BOX64`/`BOX32`; the launcher swaps the 64-bit entry for FEX or qemu depending on the run (see Performance) and keeps `BOX32`, so box64 still handles 32-bit x86 helpers. |
| **buildFHSEnv** + `pkgs/x86-libs.nix` + uname shim | Vivado needs an FHS layout (`/bin/bash` for its launcher scripts), genuine **x86-64** system libraries for the emulator to load, and a `uname -m` that says `x86_64` — its own `bin/vivado` → `bin/loader` scripts run natively as bash and abort with `Unsupported architecture: aarch64`. |

## Performance

Measured on this machine (M1 Pro), same guest, same workload:

| Workload | qemu-x86_64 | FEX |
|---|---|---|
| `vivado -version` (full launcher chain) | 10.2s | **3.5s** |
| Tcl batch, loads 504-part device DB | ~5 min | **14s** |

**The launcher picks per run**, because neither emulator wins outright:

- `-mode batch` / `-mode tcl` → **FEX** (the numbers above)
- everything else, i.e. the GUI → **qemu**

FEX cannot run the GUI. The JVM segfaults inside its own JIT-generated code
before the window appears (confirmed on FEX 2604 and 2608). `FEX_SMCCHECKS=full`
does stop the crash — it checks every store, which is what a self-patching JIT
needs — but it then costs so much that GUI startup ran past 6 minutes against
qemu's ~2. So the GUI stays on qemu until FEX handles the JVM better.

Two things make FEX work here that are easy to get wrong:

- **The rootfs needs a real `ld-linux-x86-64.so.2`, not a symlink.** FEX resolves a
  guest ELF's interpreter path inside the rootfs and cannot follow a symlink pointing at
  an absolute `/nix/store` path — it fails with `Invalid or Unsupported elf file ...
  misconfigured x86-64 RootFS`. `pkgs/x86-libs.nix` copies the loader for this reason.
  nixpkgs' own x86_64 binaries hide the problem, because they embed an absolute
  `/nix/store` interpreter path and never consult the rootfs at all.
- **binfmt flags must be `F` only.** `C` (credentials) shifts the guest's argv, so Vivado
  saw `argv[0]` as `-longversion` instead of `vivado` — and its launcher picks which tool
  to run from `basename($0)`, so that silently runs the wrong thing. `O` mangles it too,
  and `P` breaks the guest outright.

## Why not box64 (and why box86 can't run here)

The goal was box64/box86 as the bridge. Both were implemented and tested; here is where each stands.

**box64 works** — it runs ordinary x86-64 binaries on this host, and loads 50+ of Vivado's
own libraries. But it **cannot load Vivado 2025.2**: while relocating
`libxv_isl_iostreams.so` (29 MB) it misreads a symbol name and dies with

```
Error: Symbol m not found, cannot apply R_X86_64_JUMP_SLOT ... (ver=0 / (none))
SIGSEGV
```

That library contains 1087 valid `JUMP_SLOT` relocations and **no symbol named `m`** — the
real symbol is a mangled C++ name ending in `m`. The failure is byte-identical across
box64 **0.4.2 and 0.4.4**, at **16 KB and 4 KB** pages, with dynarec on/off, and with every
relevant knob (`BOX64_MMAP32`, `BOX64_MALLOC_HACK=0|1|2`, `BOX64_EMULATED_LIBS`) and both
Vivado's bundled and a modern nixpkgs `libstdc++`. So it is an upstream box64 bug, not a
configuration problem — worth reporting at https://github.com/ptitSeb/box64/issues.
qemu-x86_64 runs the same binary correctly, so the launcher uses qemu for 64-bit and keeps
box64 for 32-bit (`BOX32`).

**box86 cannot execute on Apple Silicon at all.** It ships as an **armv7l** (32-bit ARM)
binary by design — it dlopens native 32-bit ARM libraries — and Apple Silicon cores have no
AArch32 EL0, so the plain binary fails with `exec format error`. `pkgs/box86.nix` wraps it
to run nested under `qemu-arm`, which does work, but box64 0.4.4's built-in `BOX32` covers
32-bit x86 more sensibly, so nothing depends on box86.

## Setup

1. Add the module and overlay to your NixOS config:

   ```nix
   {
     inputs.xilinx-fex.url = "github:KaitoTLex/xilinx-fex";
     nixosModules = [ inputs.xilinx-fex.nixosModules.default ];
     nixpkgs.overlays = [ inputs.xilinx-fex.overlays.default ];
     nixpkgs.config.allowUnfree = true;

     programs.vivado.enable = true;
   }
   ```

2. Create `~/.config/xilinx/nix.sh` pointing at your install:

   ```sh
   INSTALL_DIR=$HOME/.Xilinx/Xilinx   # dir containing <VERSION>/Vivado/bin/vivado
   VERSION=2025.2
   ```

3. `sudo nixos-rebuild switch`, then `nix run .#vivado`.

Requires `/dev/kvm` (muvm runs a real microVM).

## Installing Vivado

```sh
nix run .#xilinx-shell
```

Drops into the FHS shell with a fake `x86_64` `uname` so `./xsetup` passes its arch check.
Install into `$INSTALL_DIR/$VERSION`.

## Troubleshooting

- **No output when piped.** muvm only forwards guest output to a real terminal. Run it in a
  terminal, or wrap it: `script -qec "vivado -version" /dev/null`.
- **`Unsupported architecture: aarch64`** — the uname shim was lost. It is set on `PATH`
  inside the runner deliberately; a login shell's `.zshrc` that rewrites `PATH` will undo it.
- **`error while loading shared libraries: libX.so`** — add the package to
  `pkgs/x86-libs.nix` (it must be the **x86_64** build, fetched from cache).
- **`failed to map segment from shared object`** — you are outside muvm, on 16 KB pages.
- **`/bin/bash: bad interpreter`** — you are outside the FHS env.
- **Blank / all-white GUI window** — Java AWT assumes a *reparenting* window manager and
  mislays its content window under tiling WMs (niri, sway, i3, dwm). Fixed by
  `_JAVA_AWT_WM_NONREPARENTING=1`, which the launcher sets. This is not an emulation bug:
  it hits Java GUIs on bare metal too.
- **`Invalid or Unsupported elf file ... misconfigured x86-64 RootFS`** — the rootfs loader
  is a symlink rather than a real file; see Performance above.

## Notes

- Your home directory is fully readable and writable inside the VM and the FHS sandbox —
  the whole host root is shared via virtiofs.
- The launcher carries your working directory into the guest (`XILINX_LAUNCH_PWD`), so
  Vivado starts where you ran it. Without that muvm drops you in `$HOME` and `vivado.log`
  lands there instead of in your project.
- **Cursor balloons over the window.** muvm does not forward `XCURSOR_*`, so X falls back
  to the unscaled core cursor. The launcher now passes your `XCURSOR_SIZE`/`XCURSOR_THEME`
  through and points `XCURSOR_PATH` at `~/.icons`.
