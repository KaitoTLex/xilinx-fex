{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.box64;
in
{
  options.programs.box64 = {
    enable = lib.mkEnableOption ''
      x86-64 emulation support for Xilinx tools on Apple Silicon.

      Installs muvm (4 KB-page microVM), qemu-user and box64, and registers
      box64 as the host's binfmt_misc interpreter for x86-64 ELFs.

      NOTE: the host registration only helps simple x86-64 programs. Apple
      Silicon runs 16 KB pages, which no usermode emulator can fully work
      around for large applications, so the Vivado launcher runs everything
      inside muvm's 4 KB-page guest instead. See pkgs/vivado-fhs.nix.
    '';
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
        message = "programs.box64 is only supported on aarch64-linux.";
      }
    ];

    # i686 etc. use QEMU via emulatedSystems; x86_64 is handled by the custom
    # box64 binfmt registration below (faster than qemu-x86_64-static).
    #
    # box86 (the natural i686 counterpart to box64) ships as an armv7l (32-bit
    # ARM) binary, and Apple Silicon cores have no AArch32 EL0 — they can't
    # execute 32-bit ARM code natively, so plain box86 fails with "exec format
    # error" on every Apple Silicon host (confirmed on kanade). pkgs.box86
    # here (see pkgs/box86.nix) is a wrapper that nests it under qemu-arm
    # instead, which does work (verified). The QEMU i386 binfmt below is
    # unrelated and stays as-is for any 32-bit x86 ELF the installer execs
    # directly via binfmt_misc rather than through box86.
    boot.binfmt.emulatedSystems = [
      "i386-linux"
      "i486-linux"
      "i586-linux"
      "i686-linux"
    ];
    nix.settings.extra-platforms = [
      "i386-linux"
      "i486-linux"
      "i586-linux"
      "i686-linux"
      "x86_64-linux"
    ];

    # muvm provides the 4 KB-page microVM the Xilinx launchers run inside;
    # qemu supplies qemu-x86_64 (the working x86-64 interpreter) and qemu-arm
    # (needed to run box86 at all — see pkgs/box86.nix).
    environment.systemPackages = [
      pkgs.box64
      pkgs.muvm
      pkgs.qemu
      (pkgs.callPackage ../pkgs/box86.nix { })
    ];

    boot.binfmt.registrations.x86_64-elf = {
      magicOrExtension = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'';
      mask = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
      interpreter = lib.getExe pkgs.box64;
      openBinary = false;
      matchCredentials = false;
      preserveArgvZero = false;
    };
  };
}
