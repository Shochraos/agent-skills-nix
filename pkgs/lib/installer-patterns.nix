# The imperative-installer patterns, shared by the two hermes-side payloads.
#
# Both consumers read skills from disk and have no `skill://` scheme, so this is the
# only content rule that holds for the bundled catalogue and for the skills hermes'
# curator writes for itself. Kept in one place because a rule two payloads share must
# not drift between them. Copied verbatim from the list `pkgs/hermes-skills/package.nix`
# carried inline.
{ }:
{
  banned = [
    "npx skills add"
    "npx skills init"
    "npx skills update"
  ];
}
