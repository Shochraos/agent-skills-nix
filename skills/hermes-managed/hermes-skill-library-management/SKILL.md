---
name: hermes-skill-library-management
description: "Use when auditing or removing Hermes profile skills."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, skills, inventory, bundled-skills, external-dirs, curator, sync, opt-out]
    related_skills: [hermes-agent, hermes-agent-skill-authoring]
---

# Hermes Skill Library Management

Answering "what skills do we have", removing skills, or explaining why a skill came back
all hinge on one fact: the registry, the disk, and the bundled source tree are three
different things, and a sync job reconciles them on every start. Detail on that
reconciliation lives in `references/skill-sync-mechanics.md`.

## 1. Take inventory from the sources, not from the list

`skills_list` returns what the loader *accepted* this session, not what is installed.
Read both, and report them separately:

1. Registry: `skills_list` (name + category).
2. Disk: `find "$HERMES_HOME/skills" -name SKILL.md` — never hardcode `~/.hermes`; a
   profile resolves to `$HERMES_HOME`. If `HERMES_HOME` is empty, the default home applies.
3. Externally-provided: every path in `skills.external_dirs` in `config.yaml`.

Expected three-source picture: `$HERMES_HOME/skills` (bundled-seeded, hub-installed, and
curator/local skills), the `external_dirs` trees, and the bundled source tree at
`$HERMES_BUNDLED_SKILLS` (read-only; every skill the profile *could* seed). A skill can be
absent from the registry while sitting on disk, and vice versa — say which case you mean.

**Platform-gated skills are present on disk but absent from `skills_list`.** Frontmatter
`platforms: [macos]` items are filtered on Linux and never appear in the list. Report them
as "installed but not loaded on this host", never as missing or deleted.

**`find` on the bundled tree returns zero results when the path is a symlink into the
store.** Use `find -L` (or `readlink -f` first) — an intact 58-skill tree otherwise looks
empty and you report "no bundled skills" from a false negative.

## 2. Deleting a skill is not the same as removing it

A periodic sync re-seeds bundled skills, keyed by `$HERMES_HOME/skills/.bundled_manifest`.
Pick the mechanism that matches intent:

| Intent | Do this |
|---|---|
| Drop everything bundled, keep the profile | `hermes skills opt-out --remove --yes` — writes `$HERMES_HOME/.no-bundled-skills`; later syncs seed essentials only, and `--remove` deletes unmodified bundled copies |
| Undo that decision | `hermes skills opt-in` (removes the marker) |
| Drop one bundled skill, keep the rest | Delete its directory and **keep `.bundled_manifest`** — the sync reads "in manifest, not on disk" as user-deleted and skips it |
| Drop a built-in the curator pruned | Names live in `$HERMES_HOME/skills/.curator_suppressed`; listed names are not re-seeded (essentials exempt) |

**Pitfall — deleting the whole skills directory deletes `.bundled_manifest` with it, which
inverts the outcome.** Every bundled skill then classifies as never-offered and the next
sync copies the entire bundled set back. The trigger is not the deletion, it is the missing
tracking file; the same sync runs at startup, `hermes update`, TUI launch, gateway start,
and profile seeding.

**Pitfall — an empty skills directory proves nothing on its own.** Check for the marker and
the manifest before telling the user a removal is durable. "Gone right now" and "stays
gone" are different claims; verify the second one or do not make it.

## 3. Verify the removal before reporting it

Do not stop at a fresh listing. Force one sync and read its result dict: `copied` must be 0
and the opt-out flag present. The exact invocation, plus how to resolve the Python and the
bundled dir from the launcher wrapper, is in `references/skill-sync-mechanics.md`.
Then re-run `skills_list` and state the before/after counts.

## 4. When a managed home rewrites the library under you

`cat $HERMES_HOME/.managed` names the owner of the home (e.g. `home-manager`). On a managed
home, activation and upgrade steps rewrite `config.yaml` and can re-materialize or clear
skills with no session action. When the inventory shifts mid-session, check, in order: the
`.managed` marker, config backups (`$HERMES_HOME/backups/config/*.good.*`), directory
mtimes, and `skills.external_dirs` in `config.yaml`. Report the manager, the timestamps, and
the before/after counts — never as an unexplained change and never as your own doing.

## 5. Never restore what the user deliberately removed

When `$HERMES_HOME/.no-bundled-skills` exists, an empty `$HERMES_HOME/skills` is the intended
state. Do not re-seed, do not list bundled skills as "missing", and do not offer to install
them; ask before any `hermes skills opt-in`. Skills provided by `skills.external_dirs` are
unaffected by the opt-out — if the user wants those gone too, the change belongs in the
management layer that declares that directory, not in `$HERMES_HOME/skills`.

## Related

- `references/skill-sync-mechanics.md` — manifest semantics, marker files, sync entry
  points, and the forced-sync verification recipe.
- `hermes-agent` covers Hermes configuration at large; load it for anything beyond the
  skill library.
