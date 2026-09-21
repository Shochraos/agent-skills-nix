{
  lib,
  runCommandLocal,
  hermes-agent,
  dbosk-skills,
}:
let
  dirSkills = import ../lib/dir-skills.nix {
    inherit lib;
    ignore = [ "DESCRIPTION.md" ];
  };

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

  vendored = {
    latex-writing = "${dbosk-skills}/latex-writing";
  };

  copies = builtins.foldl' (acc: entry: acc // entry) vendored perCategory;

  total = builtins.foldl' (count: entry: count + builtins.length (builtins.attrNames entry)) 0 (
    perCategory ++ [ vendored ]
  );

  names = builtins.attrNames copies;

  banned = (import ../lib/installer-patterns.nix { }).banned;
in
lib.throwIf (total != builtins.length names)
  "hermes-skills: two categories share a skill name, so the later copy would win and the earlier skill would disappear from both the payload and the package set: ${toString total} skills collapsed to ${toString (builtins.length names)} names"
  {
    payload =
      runCommandLocal "hermes-skills"
        {
          meta = {
            description = "Agent skills for hermes: the catalogue bundled with hermes-agent plus one vendored third-party skill, one directory per skill. Copied verbatim, gated only on the imperative-installer patterns; the README records why the oh-my-pi-specific ones are not enforced here.";
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
