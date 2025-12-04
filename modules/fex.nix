{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.fex;
in
{
  options.programs.fex = {
    enable = lib.mkEnableOption "Enable FEX x86 userspace emulator";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fex;
      description = "The FEX package to use.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        FEX_ROOTFS = "/var/lib/fex";
      };
      description = "Extra environment variables used inside FEX execution.";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [
      cfg.package
    ];

    # Environment variables applied system-wide so programs find FEX
    environment.variables = cfg.extraEnvironment;

    # This optionally ensures binfmt_misc for x86 → FEX
    boot.binfmt.emulatedSystems = [
      "x86_64-linux"
      "i686-linux"
    ];

    boot.binfmt.register = {
      fex-x86_64 = {
        interpreter = "${cfg.package}/bin/FEXBash";
        magicOrExtension = "7f454c46"; # ELF magic
        offset = 0;
        wrapper = true;
        preserveArgvZero = true;
      };
    };

  };
}
