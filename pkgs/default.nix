{ pkgs, ... }:
let
  callPackage = pkgs.lib.callPackageWith (pkgs // mypkgs);
  mypkgs = {
    aiursoft-tracer = callPackage ./aiursoft-tracer { };
    mtk_uartboot = callPackage ./mtk_uartboot { };
    tat-agent = callPackage ./tat-agent { };
  };
in
pkgs.lib.filterAttrs (
  k: v: !(v.meta ? platforms) || (builtins.elem pkgs.system v.meta.platforms)
) mypkgs
