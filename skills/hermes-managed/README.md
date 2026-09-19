# `skills/hermes-managed/`

Skills hermes-agent wrote for itself, promoted out of `~/.hermes/skills/`.

One directory per skill, holding a `SKILL.md` and whatever siblings it needs. The directory name
must equal the frontmatter `name`: that name is what the harness indexes, what `skill_view(name)`
takes, and what nixfiles' routing index lists, so the payload fails its build when the two differ.

`pkgs/hermes-managed-skills/` copies this tree verbatim into the `hermes-managed-skills` payload,
which nixfiles installs as a hermes `skills.external_dirs` entry. A directory added here therefore
reaches the running agent on the next rebuild, with no further wiring; nixfiles' build check does
require a routing line for it in `assets/harness-rules/hermes/SOUL.md` before the rebuild passes.

Promotion is described in that same file: hermes asks before moving anything, then adds the skill
here, adds its trigger to the routing list, and deletes the copy under `~/.hermes/skills/`.
`skills/omp-managed/` holds the oh-my-pi equivalents and `skills/shared/` the one skill both agents
load; the payloads stay separate so neither agent loads the other's internals.
