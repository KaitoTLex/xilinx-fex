# FHS shell for installing Xilinx tools on aarch64 (Apple Silicon).
#
# Same three-layer stack as the Vivado launcher (see pkgs/vivado-fhs.nix): muvm
# for 4 KB pages, qemu-x86_64 via binfmt_misc for translation, buildFHSEnv plus
# real x86_64 libs and a faked uname for the environment. The installer needs all
# of it too — xsetup is a bundled x86-64 JVM application and its own arch check
# rejects aarch64.
{
  lib,
  buildFHSEnv,
  writeShellScript,
  writeShellScriptBin,
  callPackage,
  muvm,
  box64,
}:

let
  x86Libs = callPackage ./x86-libs.nix { };
  emuSetup = callPackage ./muvm-qemu-binfmt.nix { };
  targetPkgs = import ./xilinx-common.nix;

  runScript = writeShellScript "xilinx-shell-runner" ''
    cfg="$HOME/.config/xilinx/nix.sh"
    [[ -f "$cfg" ]] && source "$cfg"

    # xsetup and Vivado's bin/* launcher scripts check `uname -m` and reject
    # anything that isn't x86_64.
    shim=$(mktemp -d)
    printf '%s\n' '#!/bin/sh' \
      'case "''${1:-}" in' \
      '  -m|-p|-i|--machine|--processor|--hardware-platform) echo x86_64 ;;' \
      '  *) exec /usr/bin/uname "$@" ;;' \
      'esac' > "$shim/uname"
    printf '%s\n' '#!/bin/sh' 'echo x86_64' > "$shim/arch"
    chmod +x "$shim/uname" "$shim/arch"
    export PATH="$shim:$PATH"

    export QEMU_LD_PREFIX="${x86Libs}"
    export LD_LIBRARY_PATH="${x86Libs}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    cat <<'EOF'
    ============================================================
    xilinx-shell — inside muvm (4 KB pages) + qemu-x86_64 binfmt

    To install Vivado / Vitis:
      1. Download the Linux installer from xilinx.com
      2. chmod +x ./FPGAs_AdaptiveSoCs_Unified_*.run && ./FPGAs_AdaptiveSoCs_Unified_*.run
      3. cd into the extracted installer directory
      4. ./xsetup        (or ./xsetup -b -c install_config.txt for batch mode)
      5. Install into $INSTALL_DIR/$VERSION, then exit this shell
      6. Create ~/.config/xilinx/nix.sh:
           INSTALL_DIR=$HOME/.Xilinx/Xilinx
           VERSION=2025.2

    uname is faked to x86_64 here; do not reset PATH (a .zshrc that rewrites
    PATH drops the shim and xsetup will abort with "Unsupported architecture").
    ============================================================
    EOF

    # bash, not the user's login shell: an interactive zsh reloads .zshrc, which
    # can rewrite PATH and silently drop the uname shim above.
    exec bash --noprofile --norc -i
  '';

  fhsEnv = buildFHSEnv {
    name = "xilinx-shell-fhs";
    inherit targetPkgs runScript;
  };

in
writeShellScriptBin "xilinx-shell" ''
  export PATH="${box64}/bin:$PATH"
  exec ${muvm}/bin/muvm --emu=box -x ${emuSetup} -i -t -- \
    ${fhsEnv}/bin/xilinx-shell-fhs "$@"
''
