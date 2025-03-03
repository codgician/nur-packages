{ pkgs, ... }:
with pkgs.lib;
let
  callPackage = callPackageWith (pkgs // mypkgs);
  mkPkgAttrs =
    path:
    pipe (builtins.readDir path) [
      (filterAttrs (_: type: type == "directory"))
      (mapAttrs (k: v: callPackage "${path}/${k}" { }))
    ];

  mypkgs = mergeAttrsList (
    (builtins.attrValues {
      uncategorized = (mkPkgAttrs ./uncategorized);
    })
    ++ [
      {
        kernelModules = mkPkgAttrs ./kernel-modules;
      }
    ]
  );
in
filterAttrsRecursive (
  k: v: v != { } && (!((v ? meta) ? platforms) || (builtins.elem pkgs.system v.meta.platforms))
) mypkgs
