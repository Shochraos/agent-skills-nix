# Onboarding an external skill

Depth for the requirement-extraction pass in SKILL.md: how to read a bundle, what to look for,
and a filled-in example.

## Fetch recipe — exact bytes, no auth

1. Enumerate before reading:
   `curl -sL "https://api.github.com/repos/<owner>/<repo>/git/trees/<ref>?recursive=1"` and
   filter the JSON down to `path` + `size`. Reading only the entry SKILL.md hides sub-skills,
   scripts, and large asset directories.
2. Fetch each file raw: `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>`.
   Raw URLs return the exact bytes the host will load; page-extraction services may hand back
   rendered metadata instead of the file.
3. Follow every relative path the entry SKILL.md resolves. Sub-skill SKILL.md files carry their
   own description and requirements; figure/dataset directories are part of the bundle even
   though they contribute nothing to the requirements list.
4. Prefer a shallow clone when you expect to install: `git clone --depth 1 <repo>`, then copy the
   skill folder into the host path.

## Requirement checklist

- Host capabilities, from frontmatter and any orchestration doc: skill support, shell access,
  subagent spawning, concurrency limits, lifecycle events.
- Runtime baseline: interpreter versions, pinned package versions plus their transitive
  constraints, helper CLIs, packaging tools.
- Per-target extras: language runtimes (R + IRkernel), GPU, external data, credentials read from
  the environment.
- Deliverable contract: what the skill must emit (e.g. a ZIP that re-tests after extraction at a
  new path) and which tools that check needs.
- Declared fallbacks: what the skill tells the agent to report when a capability is absent.

## Reporting to the user

- Three groups — host, runtime, per-target — each item marked present (with version) or missing
  on this machine.
- Quote the skill's own wording for hard requirements rather than paraphrasing.
- State the install target path separately from the prerequisites: prerequisites are facts,
  installing is a decision.
- Name structural limits (nested spawning) as limits of the run, not of the skill.

## Worked example — Paper2Agent (`github.com/jmiao24/Paper2Agent`, `skills/paper2agent/`)

- Bundle: entry SKILL.md routes to `paper2skill/` (PDFs + supplement + tables to a paper skill),
  `paper2mcp/` (research repository to a tested MCP server), `paper2agent-paper/` (its own
  paper), plus `scripts/` and `references/`.
- Host: a coding-agent host with skill support, shell access, and parallel subagent spawning;
  the coordinator launches specialists and fresh verifier agents and treats a role document as a
  description, not a running agent.
- Runtime: Python 3.10+ and git, plus `uv` (scripts run via `uv run`, environments via
  `uv venv`/`uv pip`); tested core baseline `fastmcp==4.0.3` (pulls Pydantic >=2.12) with
  `pytest` and `pytest-asyncio`, and `papermill`/`nbclient`/`ipykernel`/`jupytext` when notebook
  evidence is used; per-project environment at `<project>/<repo>-env`.
- Per-target: R + IRkernel route, native CLI tools, GPU, datasets, repository API keys through
  the environment; `zip` for the delivery check.
- Hermes fit: spawning exists but does not nest, so coordinator work stays in the top-level
  session and phase bookkeeping is manual.
