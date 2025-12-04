{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.xilinx-fex;
  fexCfg = config.programs.fex;
  muvmCfg = config.virtualisation.muvm;

in
{
  options.hardware.xilinx-fex = {
    enable = lib.mkEnableOption "Enable the combined FEX + muvm + Vivado compatibility layer";

    vivadoRuntimeLibs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = (
        with pkgs;
        [
          bash
          util-linux
          coreutils
          zlib
          lsb-release
          stdenv.cc.cc
          ncurses
          ncurses5
          xorg.libXext
          xorg.libX11
          xorg.libXrender
          xorg.libXtst
          xorg.libXi
          xorg.libXft
          xorg.libxcb
          # common requirements
          freetype
          fontconfig
          glib
          gtk2
          gtk3
          libxcrypt-legacy
          libdrm
          libgbm
          pixman
          libpng
          # For fetching project templates when creating projects
          gitMinimal
          # For the `arch` command
          toybox

          # to compile some xilinx examples
          opencl-clhpp
          ocl-icd
          opencl-headers

          # from installLibs.sh
          graphviz
          gcc
          unzip
          nettools
        ]
      );
      description = "Extra libraries required by Vivado at runtime.";
    };

    createFhs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the Vivado FHS env (via pkgs.buildFHSUserEnv if desired).";
    };
  };

  config = lib.mkIf cfg.enable {

    # Ensure muvm + fex are enabled
    programs.fex.enable = true;
    virtualisation.muvm.enable = true;

    # Install Vivado runtime libs globally so FHS can find them
    environment.systemPackages = cfg.vivadoRuntimeLibs;

    # Optional FHS environment
    environment.systemPackages = lib.mkIf cfg.createFhs ([
      (pkgs.buildFHSUserEnv {
        name = "vivado-fhs-env";
        targetPkgs = pkgs: cfg.vivadoRuntimeLibs;
        runScript = "bash";
        extraMounts = [
          {
            source = muvmCfg.root;
            target = "/usr/x86_64-linux";
            recursive = true;
          }
        ];
      })
    ]);

    # Make muvm root visible to all modules that need it
    environment.variables.MUVM_X86_ROOT = muvmCfg.root;
  };
}
