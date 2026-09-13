# One gated derivation per directory in the self-authored skills/ tree, so
# consumers can install individual managed skills. The bundled payload stays
# in ./package.nix; `default` keeps covering "all of them at once".
# Each output is a one-skill payload directory (`<name>/SKILL.md`): omp's
# skills.customDirectories scans only `<dir>/<name>/SKILL.md` and never a
# SKILL.md at the directory root.
{
  lib,
  runCommandLocal,
  src,
}:
let
  gates = import ./gates.nix { inherit lib; };

  skillDirs = builtins.readDir src;
  nonDirs = lib.filterAttrs (_: type: type != "directory") skillDirs;

  # Ungated verbatim copy of the whole tree, used only as the skill://
  # resolution universe for per-skill gates (a per-skill $out cannot see
  # sibling skills). Legal because the managed gates are fail-only: they
  # never rewrite content, so universe == delivered content. Build-time
  # dependency only — it never enters a per-skill output's runtime closure.
  universe = runCommandLocal "managed-skills-universe" { } ''
    mkdir $out
    cp -r ${src}/. $out/
  '';

  mkSkill =
    name:
    runCommandLocal "managed-${name}"
      {
        meta = {
          description = "Self-authored agent skill '${name}' in the managed-skills payload shape, carrying its gates";
          platforms = lib.platforms.all;
        };
      }
      ''
        mkdir -p $out/${name}
        cp -r ${src + "/${name}"}/. $out/${name}/
        chmod -R u+w $out

        ${gates.patternGate "$out" "*.md" gates.bannedEverywhere}
        ${gates.patternGate "$out" "SKILL.md" gates.bannedInSkillFiles}
        ${gates.resolutionGate "$out" universe}
      '';
in
lib.throwIf (nonDirs != { })
  "managed-skills: non-directory entries in skills/: ${toString (builtins.attrNames nonDirs)}"
  (
    lib.throwIf (skillDirs ? "skills")
      "managed-skills: a skill dir named 'skills' would generate managed-skills and shadow the aggregate attr"
      (builtins.mapAttrs (name: _: mkSkill name) skillDirs)
  )
