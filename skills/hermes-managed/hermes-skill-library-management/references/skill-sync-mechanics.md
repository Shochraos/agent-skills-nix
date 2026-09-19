# Bundled-skill sync: mechanism and verification

## Files that decide what is installed

All under `$HERMES_HOME/skills/` unless noted:

| File | Meaning |
|---|---|
| `.bundled_manifest` | `name:hash` per line (v2). Presence = "this bundled skill was already offered"; absence = never offered |
| `.curator_suppressed` | Built-in skills the curator pruned; never re-seeded (essentials exempt) |
| `.curator_state`, `.hub/` | Curator bookkeeping and hub installs |
| `$HERMES_HOME/.no-bundled-skills` | Opt-out marker: seed essentials only |

## Classification order per bundled skill

The sync walks every `SKILL.md` under the bundled source dir and takes the first match:

1. Name in `.curator_suppressed` (and not essential) → suppressed, skipped.
2. Name provided by an `external_dirs` tree → deferred to the external copy; a stale local
   shadow from an earlier sync is removed. External names always win.
3. Name not in `.bundled_manifest` → treated as never offered → **installed** (never
   overwriting a same-named user skill; the manifest is baselined either way).
4. Name in the manifest and present on disk → updated in place if the origin hash matches.
5. Name in the manifest and missing from disk → user deleted it → skipped.

Case 3 is why removing the manifest resurrects everything; case 5 is why a surgical delete
works only while the manifest survives.

Callers: agent startup, TUI launch, gateway start, `hermes update` maintenance, profile
seeding, and the installer. Assume "next start" unless the user disabled it.

## Resolving the paths

The launcher wrapper exports what you need — inspect it with
`readlink -f $(command -v hermes)`:

- `HERMES_BUNDLED_SKILLS` — the bundled source tree (its `share/hermes-agent/skills` entry
  is often a *symlink* into the store; use `find -L`).
- `HERMES_PYTHON` — the interpreter that can import the package.
- `HERMES_HOME` / `HERMES_REAL_HOME` — the active home.

The importable package sits in the sibling store path's `lib/python3.*/site-packages`.

## Forced-sync verification recipe

Run the sync under the runtime interpreter with an explicit bundled dir, then read the
result dict — `copied` must be 0 when an opt-out is in force:

```sh
SP=<store path>/lib/python3.*/site-packages
PY=<HERMES_PYTHON value, or the interpreter named in the wrapper>
HERMES_BUNDLED_SKILLS=<bundled tree> "$PY" -c "
import sys; sys.path.insert(0, '$SP')
from tools.skills_sync import sync_skills
r = sync_skills(quiet=True)
print({k: (len(v) if isinstance(v, list) else v) for k, v in r.items()})"
```

Fields worth reading: `copied`, `skipped`, `total_bundled` (essentials-only value when
opted out), `shadowed_by_external`, `skipped_opt_out`, `suppressed`, `cleaned`.

Then confirm on disk: `find "$HERMES_HOME/skills" -mindepth 1 -name SKILL.md | wc -l`, and
re-run `skills_list` to compare registry counts. A category `DESCRIPTION.md` and a baselined
`.bundled_manifest` are expected by-products of a sync that copied no skills.

**A deleted category `DESCRIPTION.md` returns on the next sync.** In opt-out mode
`_seed_category_descriptions` is restricted to the categories of `ESSENTIAL_SKILLS` — only
`hermes-agent`, whose category directory is `autonomous-ai-agents/` — and it seeds the blurb
whether or not that skill was itself deferred to an `external_dirs` tree. Deleting
`skills/autonomous-ai-agents/DESCRIPTION.md` therefore undoes itself at the next sync (observed by
running `sync_skills` against a copy of the profile under a scratch `HERMES_HOME`: `copied: 0`,
`skipped_opt_out: True`, file present afterwards). Never report that deletion as durable.

**Deferral and shadow cleanup cover bundled names only.** `_defer_to_external` runs inside the
walk over the bundled set, so a self-written skill promoted into an `external_dirs` tree keeps its
local copy — nothing else reconciles it, and removing that copy is a manual step of promotion.
Verified by deleting one: `skills_list` still returns the skill from the external tree, and its
category changes from the local directory's to `null`.
