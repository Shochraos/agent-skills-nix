# `name -> path` for every directory in a skills tree, used both to generate a
# payload's copy commands and to enumerate its per-skill packages from one place.
#
# A non-directory entry outside `ignore` is an eval error: payloads copy whole
# trees, so a stray file would ship to agents without ever becoming a selectable
# skill. `ignore` is an argument of the imported helper rather than of the call,
# because a tree either interleaves documentation with its skills or it does not
# — that is a property of the source, not of the call site.
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
