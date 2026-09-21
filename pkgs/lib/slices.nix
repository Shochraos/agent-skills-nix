{ lib, runCommandLocal }:
payloads:
let
  mkSlice =
    {
      source,
      prefix,
      payload,
    }:
    name:
    runCommandLocal "${prefix}-${name}"
      {
        meta = {
          description = "Agent skill '${name}' sliced out of the ${source} payload";
          platforms = lib.platforms.all;
        };
      }
      ''
        mkdir -p $out/${name}
        cp -r ${payload}/${name}/. $out/${name}/
        chmod -R u+w $out
      '';
in
lib.concatMapAttrs (
  source:
  {
    prefix,
    payload,
    skillNames,
  }:
  lib.listToAttrs (
    map (
      name: lib.nameValuePair "${prefix}-${name}" (mkSlice { inherit source prefix payload; } name)
    ) skillNames
  )
) payloads
