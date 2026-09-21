{
  lib,
  runCommandLocal,
  src,
}:
let
  dirSkills = import ../lib/dir-skills.nix {
    inherit lib;
    ignore = [ "README.md" ];
  };
  installerPatterns = (import ../lib/installer-patterns.nix { }).banned;
  skillNames = builtins.attrNames (dirSkills src);
in
{
  payload =
    runCommandLocal "hermes-managed-skills"
      {
        meta = {
          description = "Skills hermes-agent wrote for itself, one directory per skill, frontmatter name equal to the directory name";
          platforms = lib.platforms.all;
        };
      }
      ''
        mkdir -p $out
        cp -r ${src}/. $out/
        chmod -R u+w $out

        for skill in $out/*/; do
          [ -d "$skill" ] || continue
          name=$(basename "$skill")

          if [ ! -f "$skill/SKILL.md" ]; then
            echo "hermes-managed-skills: $name has no SKILL.md" >&2
            exit 1
          fi

          declared=$(sed -n 's/^name:[[:space:]]*//p' "$skill/SKILL.md" | sed -n 1p)
          if [ "$declared" != "$name" ]; then
            echo "hermes-managed-skills: $name/SKILL.md declares name '$declared' — the directory name is what the harness indexes and what nixfiles' routing check matches, so the two must agree" >&2
            exit 1
          fi
        done

        for pattern in ${lib.escapeShellArgs installerPatterns}; do
          if grep -rnF --include='*.md' -- "$pattern" $out; then
            echo "hermes-managed-skills: banned pattern '$pattern' present at the sites above" >&2
            exit 1
          fi
        done
      '';

  inherit skillNames;
}
