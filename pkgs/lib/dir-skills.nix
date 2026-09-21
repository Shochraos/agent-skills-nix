{
  lib,
  ignore ? [ ],
}:
dir:
let
  entries = removeAttrs (builtins.readDir dir) ignore;
  nonDirs = lib.filterAttrs (_: type: type != "directory") entries;
in
lib.throwIf (nonDirs != { })
  "${toString dir}: non-directory entries: ${toString (builtins.attrNames nonDirs)}"
  (lib.mapAttrs (name: _: dir + "/${name}") entries)
