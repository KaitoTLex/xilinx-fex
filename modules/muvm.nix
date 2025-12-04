{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.virtualisation.muvm;
  muvmRoot = "/run/muvm/x86_64-linux";

in
{
  options.virtualisation.muvm = {
    enable = lib.mkEnableOption "Enable the multi-userland virtual mount (muvm) environment";

    arch = lib.mkOption {
      type = lib.types.enum [ "x86_64-linux" ];
      default = "x86_64-linux";
      description = "Target userspace architecture to expose.";
    };

    root = lib.mkOption {
      type = lib.types.str;
      default = muvmRoot;
      readOnly = true;
      description = "Generated root for the muvm filesystem.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Ensure the muvm root exists
    systemd.tmpfiles.rules = [
      "d ${muvmRoot} 0755 root root -"
      "d ${muvmRoot}/lib 0755 root root -"
      "d ${muvmRoot}/lib64 0755 root root -"
      "d ${muvmRoot}/usr 0755 root root -"
      "d ${muvmRoot}/usr/lib 0755 root root -"
    ];

    # Generate dynamic systemd mount units for x86_64 derivations
    systemd.mounts =
      let
        # Grab x86_64 store paths
        x86Store = pkgs.lib.systems.examples.x86_64-linux;
        x86Pkgs = import pkgs.path { system = "x86_64-linux"; };
        storePaths = map (p: p.outPath) (builtins.attrValues x86Pkgs);
      in
      builtins.map (path: {
        what = path;
        where = "${muvmRoot}/nix/store/${baseNameOf path}";
        type = "none";
        options = "bind,ro";
        wantedBy = [ "multi-user.target" ];
      }) storePaths;

    # Export to other modules
    environment.etc."muvm-root".text = cfg.root;
  };
}
