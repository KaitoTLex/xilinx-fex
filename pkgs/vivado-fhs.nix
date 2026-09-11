# Xilinx Vivado / Vitis on aarch64-linux (Apple Silicon).
#
# Three problems have to be solved at once, and each layer here solves exactly one:
#
# 1. PAGE SIZE. Apple Silicon kernels use 16 KB pages; x86-64 ELF segments are
#    4 KB aligned, so qemu-user cannot map them ("failed to map segment from
#    shared object"). muvm boots a lightweight 4 KB-page microVM (libkrun/KVM,
#    sharing the host filesystem), which is where everything below runs.
#
# 2. TRANSLATION. Inside the guest, x86-64 ELFs are routed through binfmt_misc.
#    muvm registers box64 (as BOX64 + BOX32); we swap the 64-bit entry for FEX,
#    because box64 cannot load Vivado at all and FEX is ~3x faster than qemu
#    (10.19s -> 3.48s on `vivado -version`). BOX32 is left in place, so box64
#    still handles any 32-bit x86 helper. See muvm-fex-binfmt.nix.
#
# 3. ENVIRONMENT. Vivado wants an FHS layout (/bin/bash for its launcher
#    scripts, /usr/lib, fonts), real x86_64 system libraries for qemu to load,
#    and a uname that says x86_64 — its own bin/vivado -> loader scripts run
#    natively as bash and abort with "Unsupported architecture: aarch64".
{
  lib,
  buildFHSEnv,
  makeDesktopItem,
  symlinkJoin,
  writeShellScript,
  writeShellScriptBin,
  runCommand,
  callPackage,
  muvm,
  box64,
  product ? "Vivado",
}:

let
  name = lib.strings.toLower product;
  targetPkgs = import ./xilinx-common.nix;
  x86Libs = callPackage ./x86-libs.nix { };
  fexRootfs = callPackage ./fex-rootfs.nix { };

  fexSetup = callPackage ./muvm-fex-binfmt.nix { };
  qemuSetup = callPackage ./muvm-qemu-binfmt.nix { };

  # Runs inside the FHS env, inside the guest.
  runScript = writeShellScript "xilinx-${name}-runner" ''
    set -euo pipefail
    cfg="$HOME/.config/xilinx/nix.sh"
    if [[ ! -f "$cfg" ]]; then
      echo "xilinx-fex: error: $cfg not found" >&2
      echo "Create it and set INSTALL_DIR and VERSION." >&2
      exit 1
    fi
    source "$cfg"
    : "''${INSTALL_DIR:?INSTALL_DIR must be set in $cfg}"
    : "''${VERSION:?VERSION must be set in $cfg}"

    bin="$INSTALL_DIR/$VERSION/${product}/bin/${name}"
    if [[ ! -x "$bin" ]]; then
      echo "xilinx-fex: error: not found or not executable: $bin" >&2
      exit 1
    fi

    # $bin is Xilinx's own bash launcher; it and bin/loader gate on
    # `uname -m` == x86_64 before exec'ing the real ELF, so shim both uname
    # and arch. Keep this on PATH rather than in a login shell's rc — a user
    # zshrc can rewrite PATH and silently undo it.
    shim=$(mktemp -d)
    trap 'rm -rf "$shim"' EXIT
    printf '%s\n' '#!/bin/sh' \
      'case "''${1:-}" in' \
      '  -m|-p|-i|--machine|--processor|--hardware-platform) echo x86_64 ;;' \
      '  *) exec /usr/bin/uname "$@" ;;' \
      'esac' > "$shim/uname"
    printf '%s\n' '#!/bin/sh' 'echo x86_64' > "$shim/arch"
    chmod +x "$shim/uname" "$shim/arch"
    export PATH="$shim:$PATH"

    # Vivado's GUI is Java/Swing on a bundled JRE 21 (libawt_xawt.so); the window
    # class is still "ui-PlanAhead". Java2D's X11 pipeline uses MIT-SHM and
    # offscreen pixmaps, and neither survives muvm's proxied X socket: the client
    # sees a unix socket, assumes the server is local, and tries to share memory
    # with an X server living outside the VM. Every blit then silently does
    # nothing and the window stays pure white (verified with xwd: one unique
    # colour, #FFFFFF, across all 2.8M pixels, while the JVM spun at 86% CPU).
    # Force server-side pixmaps and the plain X11 blit pipeline.
    # niri (like i3/sway/dwm) is a NON-REPARENTING window manager. AWT assumes a
    # reparenting WM and offsets its content window by the decorations it expects
    # -- observed as a 1995x1264 "Content window" at (-5,-25) inside a 1494x1882
    # frame, i.e. laid out for a geometry the WM never gave it, leaving the frame
    # pure white. This env var is the long-standing fix; without it Java GUIs go
    # blank under every tiling WM, emulation or not.
    export _JAVA_AWT_WM_NONREPARENTING=1
    export J2D_PIXMAPS=server
    export JAVA_TOOL_OPTIONS="-Dsun.java2d.pmoffscreen=false -Dsun.java2d.xrender=false -Dsun.java2d.opengl=false"

    # Where the emulator finds the x86_64 loader and system libs. Both variables
    # are harmless to the other emulator, so set both rather than branching.
    # Vivado's own loader script appends its lib/lnx64.o dirs to LD_LIBRARY_PATH.
    export FEX_ROOTFS="${fexRootfs}"
    export QEMU_LD_PREFIX="${x86Libs}"
    export LD_LIBRARY_PATH="${x86Libs}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Without these the guest has no cursor theme and X falls back to the unscaled
    # core cursor -- it visibly balloons when the pointer crosses into the window.
    # Defaults match a standard HiDPI setup; the launcher forwards the host's values.
    export XCURSOR_SIZE="''${XCURSOR_SIZE:-24}"
    export XCURSOR_THEME="''${XCURSOR_THEME:-Adwaita}"
    export XCURSOR_PATH="$HOME/.icons:$HOME/.local/share/icons:/usr/share/icons"

    # Back to the directory the user launched from (see launcher below).
    cd "''${XILINX_LAUNCH_PWD:-$HOME}" 2>/dev/null || cd "$HOME"

    exec "$bin" "$@"
  '';

  fhsEnv = buildFHSEnv {
    name = "${name}-fhs";
    inherit targetPkgs runScript;
  };

  # What the user actually runs: boot the 4K-page microVM, fix up binfmt, then
  # enter the FHS env. box64 is on PATH because muvm --emu=box registers it
  # (we keep its BOX32 entry for 32-bit x86 helpers).
  launcher = writeShellScriptBin name ''
    export PATH="${box64}/bin:$PATH"
    # muvm starts the guest command in $HOME, so the directory you launched from
    # is otherwise lost -- Vivado would write vivado.log/.jou into $HOME and open
    # its file dialogs there instead of in your project. Carry it across.
    # Which emulator: measured on this machine, FEX runs batch work ~20x faster
    # than qemu (Tcl device-DB load: 5 min -> 14s). But FEX cannot run the GUI:
    # the JVM segfaults in its own JIT-generated code, and the FEX_SMCCHECKS=full
    # workaround that stops the crash slows GUI startup past 6 minutes. qemu runs
    # the GUI fine. So pick per run rather than compromising one of them.
    emu="${qemuSetup}"
    case " $* " in
      *" -mode batch "*|*" -mode tcl "*) emu="${fexSetup}" ;;
    esac
    exec ${muvm}/bin/muvm --emu=box -x "$emu" -e XILINX_LAUNCH_PWD="$PWD" \
      -e XCURSOR_SIZE="''${XCURSOR_SIZE:-24}" -e XCURSOR_THEME="''${XCURSOR_THEME:-Adwaita}" \
      -i -t -- \
      ${fhsEnv}/bin/${name}-fhs "$@"
  '';

  desktopItem = makeDesktopItem {
    inherit name;
    desktopName = product;
    comment = "Xilinx ${product} (aarch64 via muvm + FEX/qemu)";
    exec = "${launcher}/bin/${name} %U";
    icon = name;
    categories = [
      "Development"
      "Electronics"
    ];
    terminal = false;
  };

  iconDrvs = {
    vivado = [
      (runCommand "${name}-icon" { } ''
        install -Dm644 ${../icons/vivado.png} \
          $out/share/icons/hicolor/256x256/apps/${name}.png
      '')
    ];
    vitis_hls = [
      (runCommand "${name}-icon" { } ''
        install -Dm644 ${../icons/vitis_hls.png} \
          $out/share/icons/hicolor/256x256/apps/${name}.png
      '')
    ];
    vitis = [ ];
    model_composer = [
      (runCommand "${name}-icon" { } ''
        install -Dm644 ${../icons/matlab.png} \
          $out/share/icons/hicolor/256x256/apps/${name}.png
      '')
    ];
  };

in
symlinkJoin {
  inherit name;
  paths = [
    launcher
    desktopItem
  ]
  ++ (iconDrvs.${name} or [ ]);
  meta = {
    description = "Xilinx ${product} on aarch64 via muvm (4K pages), FEX for batch / qemu for GUI";
    platforms = [ "aarch64-linux" ];
    # MIT, not unfree: this derivation is a 44 KB launcher script plus a .desktop
    # entry and icon. It contains no Xilinx code and redistributes nothing --
    # Vivado stays in the user's own $INSTALL_DIR, outside the store, under AMD's
    # licence. Marking it unfree would force --impure and NIXPKGS_ALLOW_UNFREE on
    # every `nix run` for no benefit. Flip it back if you'd rather be conservative.
    license = lib.licenses.mit;
    mainProgram = name;
  };
}
