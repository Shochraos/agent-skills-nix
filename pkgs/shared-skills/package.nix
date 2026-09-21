{
  lib,
  runCommandLocal,
  src,
}:
let
  gates = import ../lib/skill-gates.nix {
    inherit lib;
    name = "shared-skills";
  };
  skillNames = builtins.attrNames (import ../lib/dir-skills.nix { inherit lib; } src);
in
{
  payload =
    runCommandLocal "shared-skills"
      {
        meta = {
          description = "Self-authored agent skills shared by oh-my-pi and hermes-agent";
          platforms = lib.platforms.all;
        };
      }
      ''
        mkdir -p $out
        cp -r ${src}/. $out/
        chmod -R u+w $out

        ${gates.patternGate "$out" "*.md" gates.bannedEverywhere}
        ${gates.patternGate "$out" "SKILL.md" gates.bannedInSkillFiles}

        ${gates.resolutionGate "$out" "$out"}
      '';

  inherit skillNames;
}
