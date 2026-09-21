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
