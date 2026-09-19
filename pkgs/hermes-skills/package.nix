{
  lib,
  runCommandLocal,
  hermes-agent,
}:
let
  dirSkills = import ../lib/dir-skills.nix {
    inherit lib;
    ignore = [ "DESCRIPTION.md" ];
  };

  # `skills/` itself also holds AGENTS.md and index-cache, so the walk starts one
  # level down, at the categories.
  categories = [
    "apple"
    "autonomous-ai-agents"
    "creative"
    "devops"
    "email"
    "media"
    "note-taking"
    "productivity"
    "research"
    "social-media"
    "software-development"
    "web"
  ];

  perCategory = map (category: dirSkills "${hermes-agent}/skills/${category}") categories;

  copies = builtins.foldl' (acc: entry: acc // entry) { } perCategory;

  total = builtins.foldl' (
    count: entry: count + builtins.length (builtins.attrNames entry)
  ) 0 perCategory;

  # Two categories sharing a skill name would make the later copy win, and the
  # per-skill package list is derived from this same attrset, so the lost skill
  # would vanish from both the payload and the package set with nothing failing.
  names = builtins.attrNames copies;

  # Deliberately narrower than vendored-skills' gate set, and measured rather
  # than assumed: over the skills consumers select, `git commit`, `git push`,
  # `git add` and sibling `references/` paths appear only in hermes' own idiom.
  # hermes reads skills from disk, so those relative paths are correct for its
  # consumer, and rewriting them to `skill://` would fix omp at hermes' expense.
  # Only the imperative-installer class is universal, and it measures zero hits.
  banned = [
    "npx skills add"
    "npx skills init"
    "npx skills update"
  ];
in
lib.throwIf (total != builtins.length names)
  "hermes-skills: two categories share a skill name, so the later copy would win and the earlier skill would disappear from both the payload and the package set: ${toString total} skills collapsed to ${toString (builtins.length names)} names"
  {
    payload =
      runCommandLocal "hermes-skills"
        {
          meta = {
            description = "Agent skills bundled with hermes-agent, one directory per skill. Copied verbatim; see the gate comment in package.nix for why the sibling-path and git patterns are not enforced.";
            platforms = lib.platforms.all;
          };
        }
        ''
          mkdir -p $out
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: source: "cp -r ${source} $out/${name}") copies
          )}
          chmod -R u+w $out

          for pattern in ${lib.escapeShellArgs banned}; do
            if grep -rnE --include='*.md' -- "$pattern" $out; then
              echo "hermes-skills: banned pattern '$pattern' present at the sites above" >&2
              exit 1
            fi
          done

          copied=$(find $out -mindepth 1 -maxdepth 1 -type d | wc -l)
          [ "$copied" -eq ${toString (builtins.length names)} ] || {
            echo "hermes-skills: copied $copied directories, expected ${toString (builtins.length names)}" >&2
            exit 1
          }
        '';

    skillNames = names;
  }
