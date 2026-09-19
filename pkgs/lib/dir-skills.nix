# `name -> path` for every directory in a skills tree, used both to generate a
# payload's copy commands and to enumerate its per-skill packages from one place.
#
# A non-directory entry is an eval error: payloads copy whole trees, so a stray
# file would ship to agents without ever becoming a selectable skill.
{ lib }:
dir:
let
  entries = builtins.readDir dir;
  nonDirs = lib.filterAttrs (_: type: type != "directory") entries;
in
lib.throwIf (nonDirs != { })
  "${toString dir}: non-directory entries: ${toString (builtins.attrNames nonDirs)}"
  (lib.mapAttrs (name: _: dir + "/${name}") entries)
