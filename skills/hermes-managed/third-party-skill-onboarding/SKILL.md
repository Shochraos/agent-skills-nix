---
name: third-party-skill-onboarding
description: "Use when asked what a third-party agent skill needs."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [skills, third-party, vetting, installation, requirements, host-capabilities]
    related_skills: [hermes-skill-library-management, hermes-agent]
---

# Third-Party Skill Onboarding

Vetting an agent skill that did not come from this library: "what do I need to run <skill>?" is
a requirements question. Answer it from the skill's own files and from this machine, keep what
is missing separate from what the user decides, and do not install as part of answering —
offer it.

## 1. Read the upstream bundle, not search results

1. Enumerate the folder before reading anything: GitHub tree API with `?recursive=1` — reading
   only the entry SKILL.md hides sibling sub-skills and their scripts.
2. Fetch each file raw (`curl -sL https://raw.githubusercontent.com/...`). Search-result
   snippets reorder frontmatter and drop subdirectories; raw URLs give the exact bytes the host
   will load.
3. Follow every relative path the entry SKILL.md resolves. A SKILL.md pointing at
   `paper2skill/SKILL.md` or `references/runtime.md` describes a *bundle*: the whole folder is
   the install unit, not the top-level file.
4. Read the sub-skill and reference files that carry requirements — runtime baselines and
   orchestration docs live there, not in the entry file.

Recipe with exact commands: `references/external-skill-onboarding.md`.

## 2. Split requirements three ways

- **Host:** capabilities the skill demands of the agent runtime — skill support, shell access,
  subagent spawning, concurrency. Quote the skill's own wording for hard ones (e.g. "requires a
  host with agent spawning", "skill support, shell access, and parallel subagent spawning
  enabled").
- **Runtime:** interpreter versions, pinned packages and their transitive constraints, helper
  CLIs, packaging tools. A pinned core dependency usually drags a minimum of another
  (`fastmcp==4.0.3` needs Pydantic >=2.12) — report the pair, not just the pin.
- **Per-target:** what the repository or paper being processed needs — R/IRkernel, native
  compilers, GPU, external data, credentials read from the environment.

## 3. Assess this machine and report three groups

Probe each requirement rather than assuming:

```bash
for c in git python3 uv pip3 node npm R Rscript jupyter pandoc zip; do
  printf '%-10s ' "$c"
  command -v "$c" >/dev/null 2>&1 && $c --version 2>&1 | head -1 || echo MISSING
done
```

Report present items with their versions and missing items as installs to perform. A missing
binary is an install instruction, never a verdict that the skill cannot work. Note where the
skill's baseline conflicts with what is installed — an interpreter newer than the pinned range
is a conflict, not a pass.

## 4. Host-capability traps

- **Subagents do not nest.** A coordinator-driven skill whose coordinator "launches
  specialists and fresh verifier agents" must run from the top-level session; the per-phase
  records it derives from host lifecycle events (agent IDs, handoff hashes, phase markers) have
  to be maintained by hand. Check the skill's own fallback wording — good ones declare what to
  report when spawning is unavailable.
- **Skill path differs per host:** `$HERMES_HOME/skills/<name>/` (Hermes),
  `~/.claude/skills/<name>` (Claude Code), `~/.agents/skills/<name>` (Codex). Copy the entire
  bundle into it.
- **Credentials** are passed through the environment; a skill that says so must not receive a
  key pasted into a prompt, a file, or a command line.
- **Delivery checks need tools too.** A skill that ships a ZIP which re-tests after extraction
  at a new path needs the packaging tool installed before the run, not discovered at the end.

## 5. Installing is the user's decision

An empty `$HERMES_HOME/skills` is often the intended state in this profile; installing into it
is a user decision, so show what would be installed and ask. Skills this profile owns are
promoted into the user's skills repository immediately and without asking, never left as a
local-only copy (`hermes-skill-library-management` has the mechanics).

## Related

- `references/external-skill-onboarding.md` — fetch recipe, requirements checklist, and a
  worked requirements profile for a third-party skill.
- `hermes-skill-library-management` (externally shipped, read-only to curation) covers local
  inventory, removal, and sync mechanics once a skill is installed.
