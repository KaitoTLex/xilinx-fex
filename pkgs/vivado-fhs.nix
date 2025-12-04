{
  pkgs,
  muvmRoot ? "/run/muvm/x86_64-linux",
}:

pkgs.buildFHSUserEnvBubblewrap rec {
  name = "vivado-fhs";

  targetPkgs = pkgs': [
    pkgs'.glibc
    pkgs'.zlib
    pkgs'.openssl
    pkgs'.ncurses5
    pkgs'.xorg.libX11
    pkgs'.xorg.libXext
    pkgs'.xorg.libXrender
    pkgs'.gtk3
    pkgs'.fontconfig
  ];

  inherit (pkgs) box64;

  extraMounts = [
    {
      source = muvmRoot;
      target = "/usr/x86_64-linux";
      recursive = true;
    }
  ];

  extraBwrapArgs = [
    "--setenv"
    "MUVM_X86_ROOT"
    muvmRoot
  ];

  runScript = "bash";
}
