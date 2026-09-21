{
  lib,
  runCommandLocal,
  src,
}:
let
  gates = import ../lib/skill-gates.nix {
    inherit lib;
    name = "omp-managed-skills";
  };
  skillNames = builtins.attrNames (import ../lib/dir-skills.nix { inherit lib; } src);
in
{
  payload =
    runCommandLocal "omp-managed-skills"
      {
        meta = {
          description = "Self-authored oh-my-pi agent skills, gated for the same contract as the vendored payloads";
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
