{ lib, name }:
let
  noTrailingNewline = lib.removeSuffix "\n";
in
{
  bannedEverywhere = [
    "git commit"
    "git push"
    "npx skills add"
    "npx skills init"
    "npx skills update"
    "(^|[^/])references/"
  ];

  bannedInSkillFiles = [
    "git add"
    "\\]\\(\\.\\./"
    "release-process"
  ];

  patternGate = root: include: patterns: ''
    for pattern in ${lib.escapeShellArgs patterns}; do
      if grep -rnE --include=${lib.escapeShellArg include} -- "$pattern" ${root}; then
        echo "${name}: banned pattern '$pattern' present in ${include} at the sites above" >&2
        exit 1
      fi
    done
  '';

  resolutionGate =
    scanRoot: universeRoot:
    noTrailingNewline ''
      unresolved=0
      for target in $(grep -rhoE 'skill://[A-Za-z0-9_./-]+' --include='*.md' ${scanRoot} | sort -u); do
        [ -e "${universeRoot}/''${target#skill://}" ] && continue
        echo "${name}: '$target' resolves to nothing:" >&2
        grep -rnF --include='*.md' -- "$target" ${scanRoot} >&2
        unresolved=1
      done
      [ "$unresolved" -eq 0 ]
    '';
}
