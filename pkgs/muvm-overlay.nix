final: prev:

{
  muvm-utils = prev.writeShellScriptBin "muvm-init" ''
    #!/usr/bin/env bash
    set -e

    ROOT="/run/muvm/x86_64-linux"

    echo "Initializing muvm root at $ROOT"

    mkdir -p $ROOT/{nix/store,usr,usr/lib,lib,lib64}

    echo "Mounting x86_64-linux store paths..."
    for drv in $(nix-store --query --requisites $(nix-instantiate --eval -E 'with import <nixpkgs> { system = "x86_64-linux"; }; builtins.attrValues pkgs')); do
      name=$(basename "$drv")
      mkdir -p "$ROOT/nix/store/$name"
      mount --bind "$drv" "$ROOT/nix/store/$name"
      mount -o remount,ro,bind "$ROOT/nix/store/$name"
    done

    echo "muvm root ready."
  '';
}
