{ config, lib, pkgs, ... }:

let
  cfg = config.programs.vivado;
in
{
  imports = [ ./box64.nix ];

  options.programs.vivado = {
    enable = lib.mkEnableOption ''
      Xilinx Vivado on aarch64-linux via box64.

      Installs the Vivado FHS wrapper and enables box64 binfmt registration.

      You must also apply overlays.default from this flake to your nixpkgs:
        nixpkgs.overlays = [ xilinx-fex.overlays.default ];

      And create ~/.config/xilinx/nix.sh:
        export INSTALL_DIR=~/.Xilinx
        export VERSION=2024.2
    '';
  };

  config = lib.mkIf cfg.enable {
    programs.box64.enable = lib.mkDefault true;

    environment.systemPackages = [
      (pkgs.callPackage (toString ../pkgs/vivado-fhs.nix) { })
    ];
  };
}
