{
  description = "Xilinx Vivado on NixOS/Asahi using FEX + muvm + FHS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import ./pkgs/fex-overlay.nix)
            (import ./pkgs/muvm-overlay.nix)
          ];
        };

        muvmRoot = "/run/muvm/x86_64-linux";

        vivadoFhs = import ./pkgs/vivado-fhs.nix {
          inherit pkgs muvmRoot;
        };
      in
      {

        # -------------------------
        # Export Packages
        # -------------------------
        packages = {
          inherit vivadoFhs;

          # Export scripts
          enter-fex-env = pkgs.writeShellScriptBin "enter-fex-env" ''
            exec bash ${./scripts/enter-fex-env.sh}
          '';

          install-vivado = pkgs.writeShellScriptBin "install-vivado" ''
            exec bash ${./scripts/install-vivado.sh}
          '';
        };

        # Makes `nix run` work:
        defaultPackage = vivadoFhs;

        # -------------------------
        # Development Shell
        # -------------------------
        devShell = pkgs.mkShell {
          packages = [
            vivadoFhs
            pkgs.fex
            pkgs.muvm-utils
          ];

          shellHook = ''
            echo "Vivado FHS dev-shell active"
          '';
        };
      }
    )
    // {
      # -------------------------
      # Export NixOS modules
      # -------------------------
      nixosModules = {
        fex = import ./modules/fex.nix;
        muvm = import ./modules/muvm.nix;
        xilinx-fex = import ./modules/xilinx-fex.nix;
      };

      # -------------------------
      # Makes `nixos-rebuild` usable
      # -------------------------
      nixosConfigurations = {
        example = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";

          modules = [
            ./modules/fex.nix
            ./modules/muvm.nix
            ./modules/xilinx-fex.nix

            # Example use
            {
              programs.fex.enable = true;
              virtualisation.muvm.enable = true;
              hardware.xilinx-fex.enable = true;
            }
          ];
        };
      };
    };
}
