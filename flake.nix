{
  description = "Run Xilinx Vivado/Vitis on aarch64-linux (Apple Silicon) via muvm + x86-64 emulation";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # One definition, reused by packages/ and overlays.default.
      xilinxPackages = final: {
        vivado = final.callPackage ./pkgs/vivado-fhs.nix { };
        vitis = final.callPackage ./pkgs/vivado-fhs.nix { product = "Vitis"; };
        vitis_hls = final.callPackage ./pkgs/vivado-fhs.nix { product = "Vitis_HLS"; };
        xilinx-shell = final.callPackage ./pkgs/xilinx-shell.nix { };
        box86 = final.callPackage ./pkgs/box86.nix { };
        x86-libs = final.callPackage ./pkgs/x86-libs.nix { };
      };

      built = xilinxPackages pkgs;

      # Everything with a binary of the same name, so `nix run .#vitis` works.
      runnable = {
        inherit (built)
          vivado
          vitis
          vitis_hls
          xilinx-shell
          ;
      };
    in
    {
      packages.${system} = built // {
        default = built.vivado;
      };

      apps.${system} = (
        builtins.mapAttrs (name: pkg: {
          type = "app";
          program = "${pkg}/bin/${name}";
          meta.description = pkg.meta.description or "Xilinx ${name}";
        }) runnable
      )
      // {
        default = {
          type = "app";
          program = "${built.vivado}/bin/vivado";
          meta.description = built.vivado.meta.description;
        };
      };

      nixosModules = {
        box64 = import ./modules/box64.nix;
        vivado = import ./modules/vivado.nix;
        default = {
          imports = [
            ./modules/box64.nix
            ./modules/vivado.nix
          ];
        };
      };

      overlays.default = final: _prev: xilinxPackages final;

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
