# Join an explicit set of per-skill packages into one skills directory, with the
# names validated at evaluation time so a typo is an eval error instead of a
# silently smaller set.
#
# symlinkJoin is enough: omp's directory scanner accepts symbolic links as skill
# entries (`c.isDirectory() || c.isSymbolicLink()`) and stats `<dir>/<name>/SKILL.md`
# through them.
{ lib, symlinkJoin }:
available: names:
let
  unknown = builtins.filter (name: !(available ? ${name})) names;
in
lib.throwIf (unknown != [ ])
  "mkSkillset: unknown skill(s) ${builtins.toJSON unknown}; available: ${builtins.toJSON (builtins.attrNames available)}"
  (symlinkJoin {
    name = "agent-skills-skillset";
    paths = map (name: available.${name}) names;
  })
