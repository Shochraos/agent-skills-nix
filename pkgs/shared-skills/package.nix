# Self-authored skills both agents load, promoted out of oh-my-pi's or hermes-agent's
# managed directory. Neither agent owns them, so they sit outside the two per-agent trees:
# oh-my-pi takes this payload whole, hermes selects from it by name.
#
# It carries the oh-my-pi gate set — the strictest of its two consumers — so a skill here
# must be readable by oh-my-pi: no sibling `references/` link, no git writes, and every
# `skill://` token resolving inside this payload. A skill that only works when read from
# disk belongs in `hermes-managed/` instead.
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
