# Self-authored skills, promoted from oh-my-pi's `~/.omp/agent/managed-skills/`.
# Unlike the other two payloads there is no upstream input: the source is this
# repo's own `skills/` tree, copied verbatim — no sed normalisation, only gates.
{
  lib,
  runCommandLocal,
  src,
}:
let
  gates = import ./gates.nix { inherit lib; };
in
runCommandLocal "managed-skills"
  {
    meta = {
      description = "Self-authored agent skills, gated for the same contract as the vendored payloads";
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
  ''
