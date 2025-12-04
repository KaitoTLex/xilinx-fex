final: prev:

{
  fex = prev.callPackage (
    {
      stdenv,
      fetchFromGitHub,
      cmake,
      SDL2,
      python3,
      zlib,
      openssl,
    }:
    stdenv.mkDerivation rec {
      pname = "fex";
      version = "unstable";

      src = fetchFromGitHub {
        owner = "FEX-Emu";
        repo = "FEX";
        rev = "main";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; # FIX THIS AFTER FIRST BUILD
      };

      nativeBuildInputs = [
        cmake
        python3
      ];
      buildInputs = [
        SDL2
        zlib
        openssl
      ];

      cmakeFlags = [
        "-DENABLE_SDL2=ON"
        "-DENABLE_GTK3=OFF"
      ];

      installPhase = ''
        mkdir -p $out/bin
        cp FEXBash $out/bin/
        cp FEXInterpreter $out/bin/
      '';
    }
  ) { };
}
