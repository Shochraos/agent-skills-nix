# Skills hermes-agent wrote for itself, promoted out of `~/.hermes/skills/`.
# No upstream input: the source is this repo's own `hermes-managed/` tree, copied
# verbatim.
#
# The gates are the hermes-side ones rather than the oh-my-pi payload's. That payload
# encodes oh-my-pi's constraints — `skill://` references, no `..` traversal, no
# git writes — while hermes reads skills from disk and has no `skill://` scheme,
# so a sibling relative path is its idiom and the resolution gate would check
# nothing. What is enforced instead is the invariant the routing index rests on:
# every directory is a skill, and its frontmatter name equals the directory name.
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
