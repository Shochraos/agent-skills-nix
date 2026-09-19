# agent-skills-nix

The agent skills behind [nixfiles](https://github.com/Shochraos/nixfiles), packaged as Nix derivations and kept fresh by a weekly auto-updater — plus one runtime package: a fully declarative Scrapling MCP server.

> **AI disclaimer:** The Nix packaging, the auto-update workflow and this README were written with AI assistance. Skill content comes from the upstream repositories listed below — except the `omp-managed-skills` and `hermes-managed-skills` payloads, which are self-authored. The packaging only rewrites paths and commands inside the upstream skills so their internal references resolve under oh-my-pi's `skill://` scheme, and it fails the build when upstream drift breaks that contract. Read what you install.

## What it packages

| Package | Upstream source | Skills | Per-skill attributes |
| --- | --- | --- | --- |
| `superpowers-skills` | [obra/superpowers](https://github.com/obra/superpowers) | 11 | `superpowers-<skill-name>` |
| `vendored-skills` | [marceloeatworld/nixos-ai-skill](https://github.com/marceloeatworld/nixos-ai-skill), [TheQtCompanyRnD/agent-skills](https://github.com/TheQtCompanyRnD/agent-skills), [vercel-labs/skills](https://github.com/vercel-labs/skills), [wshobson/agents](https://github.com/wshobson/agents), [anthropics/skills](https://github.com/anthropics/skills), one file from [github/awesome-copilot](https://github.com/github/awesome-copilot) | 29 | `vendored-<skill-name>` |
| `omp-managed-skills` | self-authored — promoted from oh-my-pi's `~/.omp/agent/managed-skills/`, source lives in this repo's `skills/omp-managed/` tree | 9 | `omp-managed-<skill-name>` |
| `shared-skills` | self-authored — read by both agents, source lives in this repo's `skills/shared/` tree | 1 | `shared-<skill-name>` |
| `hermes-managed-skills` | self-authored — promoted from hermes-agent's `~/.hermes/skills/`, source lives in this repo's `skills/hermes-managed/` tree | 2 | `hermes-managed-<skill-name>` |
| `hermes-skills` | [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) | 58 | `hermes-<skill-name>` |

The six payloads are deliberately separate derivations — needle edits, `sed` rewrites and verbatim copies respectively, with the two hermes-side payloads gated more narrowly on purpose — sharing only the `package.nix` shape, the gate snippets the two oh-my-pi-side payloads run (`pkgs/lib/skill-gates.nix`) and the installer-pattern list the two hermes-side ones refuse (`pkgs/lib/installer-patterns.nix`). Every skill is also packaged on its own, as `packages.<system>.<source>-<skill-name>`: 117 attributes in total, so a consumer installs exactly the skills it wants instead of a whole payload. Each of those is one directory copied out of its gated payload, so it is byte-identical to that skill inside the aggregate and its closure is only its own store path.

There is no `default` package — `nix build` always names an attribute.

`scrapling-runtime` is the seventh package, deliberately not a payload: it is not a skills directory, so it has no per-skill attributes. It builds a python package set (scrapling 0.4.15, mcp 2.x, patchright from the PyPI wheel — the GitHub source is not the release content) on top of nixpkgs Chromium. Its `bin/scrapling-mcp` wrapper pins the browser (`SCRAPLING_EXECUTABLE_PATH`) and the node driver binary (`PLAYWRIGHT_NODEJS_PATH`), so no FHS-linked binary ever execs: no pip venv, no browser cache, no nix-ld, no steam-run.

## How it works

- `superpowers-skills` edits upstream with literal `--replace-fail` needles (upstream rewording one of them is a build error, not silent rot) and ends with a banned-pattern gate that greps the payload for content that must never reach an agent (git write commands, hand-rolled install instructions, disabled-skill handoffs).
- `vendored-skills` edits a fast-moving upstream with `sed` rewrites (a literal needle would break on every daily doc refresh) and runs three gates: banned patterns in `*.md`, stricter banned patterns in `SKILL.md` only, and a resolution gate that walks every `skill://` token in the payload and fails if it does not name a skill that exists. Its copies and its per-skill edits are evaluation-visible data, and both the build script and the per-skill package list are generated from it, so a skill cannot be copied without becoming selectable, or selectable without being copied.
- `omp-managed-skills` copies the self-authored `skills/omp-managed/` tree verbatim — no upstream input, no rewrites — and runs the same gate set as `vendored-skills`. Promotion means copying a skill out of oh-my-pi's `~/.omp/agent/managed-skills/`; the managed copy is deleted in the same change, so this repository is the only source.
- `hermes-managed-skills` copies the `skills/hermes-managed/` tree verbatim and gates what its own consumer depends on rather than what oh-my-pi does: every directory must be a skill, its `SKILL.md` frontmatter `name` must equal the directory name — that is the name Hermes indexes and the name nixfiles' routing check matches — and the imperative-installer patterns are refused. The `skill://` resolution gate and the sibling-path rule are absent on purpose: Hermes has no `skill://` scheme and reads skills from disk. Its one skill so far is `hermes-skill-library-management`, which hermes' own curator wrote; the build tolerates an empty tree, so a promotion is a directory added here.
- `shared-skills` copies the `skills/shared/` tree verbatim and runs the oh-my-pi gate set, because oh-my-pi is the stricter of its two readers: no sibling `references/` link, no git writes, and every `skill://` token must resolve inside the payload. A skill only hermes can read belongs in `skills/hermes-managed/` instead. Its one skill so far is `cloudflare-bypass`, which oh-my-pi routes to for blocked or JS-only fetches and hermes lists among its external dirs.
- `hermes-skills` copies hermes' bundled catalogue verbatim and runs one gate: the imperative-installer patterns (`npx skills add|init|update`). Its gate set is narrower than the others for a measured reason. The `git` patterns and the sibling-`references/` rule encode oh-my-pi's constraints — omp rejects `..` traversal in `skill://` and forbids git writes — while hermes reads skills from disk, where a relative `references/` path is correct. Eight of the skills consumers select carry such paths, so enforcing the rule here would rewrite upstream content into a form its own consumer cannot follow.
- Each per-skill package is sliced out of its gated payload with `cp -r`, so the payload's gates run for any slice you build and the slice stays byte-identical to that skill directory. Eval-time guards fail the flake if a per-skill name would shadow a payload name, or if fewer skills were generated than the payloads report. `lib.<system>.mkSkillset [ … ]` joins a chosen set into one skills directory and rejects an unknown name, quoting the names that exist.
- `scrapling-runtime` overrides a scoped python package set: mcp 2.1.1 (scrapling imports a 2.x-only API), mcp-types, patchright 1.62.2, and small bumps scrapling's runtime-deps check enforces (cssselect, curl-cffi). nixpkgs' playwright 1.61 driver is kept and works through `executable_path`; that compat is proven by the smoke test, not assumed.
- `checks.<system>` carries the packages, so `nix flake check` actually builds every package — payloads through their gates, the runtime through its own build — instead of just evaluating them. The auto-updater relies on this: a red run means nothing lands.
- The seven skill sources are flake inputs; the lock is bumped by the workflow, not by hand.
- The `create-readme` skill is a `fetchurl` pinned to a commit sha inside `pkgs/vendored-skills/package.nix`. `nix flake update` can never move it; a refresh means editing the rev and its hash together.

### Auto-update

Every Monday 06:00 UTC (and on manual dispatch), the `update-skill-sources` workflow bumps the seven skill inputs, runs `nix flake check`, and pushes `flake.lock` only when the build is green and the lock actually changed. nixpkgs is deliberately not auto-bumped, so the lock diff stays focused on skills. If a gate trips, the run is red and consumers keep building the last pinned rev.
Every push to any branch (and manual dispatch) also runs the `build-packages` workflow: a fresh `nix flake check` on a clean runner, so a commit that breaks evaluation or a gate goes red right away instead of surfacing at the next weekly update.

## Usage

Add the input and install the payload directories as oh-my-pi `skills.customDirectories`:

```nix
{
  inputs.agent-skills-nix = {
    url = "github:Shochraos/agent-skills-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

```nix
{ inputs, pkgs, ... }:
{
  skills.customDirectories = [
    "${inputs.agent-skills-nix.packages.${pkgs.stdenv.hostPlatform.system}.superpowers-skills}"
    "${inputs.agent-skills-nix.packages.${pkgs.stdenv.hostPlatform.system}.vendored-skills}"
    "${inputs.agent-skills-nix.packages.${pkgs.stdenv.hostPlatform.system}.omp-managed-skills}"
    "${inputs.agent-skills-nix.packages.${pkgs.stdenv.hostPlatform.system}.shared-skills}"
  ];
}
```

Individual skills install the same way — one `customDirectories` entry, or one entry for a whole selection via `mkSkillset`:

```nix
skills.customDirectories = [
  "${inputs.agent-skills-nix.lib.${pkgs.stdenv.hostPlatform.system}.mkSkillset [
    "superpowers-brainstorming"
    "superpowers-writing-plans"
    "superpowers-executing-plans"
    "vendored-nixos"
    "omp-managed-nix-unit-in-flake"
  ]}"
];
```

`mkSkillset` joins the named per-skill packages into one directory and fails evaluation on a name that does not exist, printing the names that do.

A hermes-agent install consumes skills through its own `skills.external_dirs` instead, and a payload directory is a valid entry there. nixfiles points that at a `mkSkillset` selection plus the whole `hermes-managed-skills` payload, so a skill promoted here reaches the agent without further wiring in this repository. nixfiles' build does require a routing bullet for every name under those external dirs in `assets/harness-rules/hermes/SOUL.md` and fails without it, so a promotion lands as a change in both repositories. Skills under `skills/shared/` reach hermes the same way, selected by name from the `shared-skills` payload.

Selecting a skill on its own leaves any reference it makes to a sibling skill (`skill://<name>`, or `superpowers:<name>`) pointing at a skill you did not install: the resolution gate checks the payload, not your selection. Pick related skills together.

The Scrapling runtime wires into oh-my-pi's `mcp.json` (this is what nixfiles' ai aspect does):

```nix
home.file.".omp/agent/mcp.json".source = (pkgs.formats.json { }).generate "mcp.json" {
  "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
  mcpServers.ScraplingServer = {
    type = "stdio";
    command = "${inputs.agent-skills-nix.packages.${pkgs.stdenv.hostPlatform.system}.scrapling-runtime}/bin/scrapling-mcp";
    timeout = 120000;
  };
};
```

## Layout

```
flake.nix                             packages, checks, formatter, devshell
pkgs/lib/dir-skills.nix               the guarded name -> path map of a skills tree
pkgs/lib/slices.nix                   one derivation per skill, sliced from its payload
pkgs/lib/mk-skillset.nix              the lib.<system>.mkSkillset selection helper
pkgs/lib/skill-gates.nix              the oh-my-pi gate set, run by both oh-my-pi-side payloads
pkgs/lib/installer-patterns.nix       the installer patterns both hermes payloads refuse
pkgs/superpowers-skills/package.nix   the needle-edited payload
pkgs/vendored-skills/package.nix      the sed-edited payload
pkgs/omp-managed-skills/package.nix   the verbatim oh-my-pi self-authored payload
pkgs/shared-skills/package.nix        the verbatim payload both agents read
pkgs/hermes-managed-skills/package.nix the verbatim hermes-side self-authored payload
pkgs/hermes-skills/package.nix        hermes' bundled catalogue, copied verbatim
skills/omp-managed/                   the oh-my-pi-authored sources
skills/shared/                        the sources both agents read
skills/hermes-managed/                the hermes-authored sources
pkgs/scrapling-runtime/               the Scrapling MCP runtime + wrapper
.github/workflows/update-skill-sources.yml   the weekly auto-updater
.github/workflows/build-packages.yml   the per-commit build gate
```

## Development

`nix develop` provides `nixfmt` and `nixd`. `nix fmt` formats. `nix flake check` is the gate: `checks.<system>` carries every package plus a smoke test of `mkSkillset`, and each payload and per-skill derivation is a `runCommandLocal` whose build script runs that payload's gates, so a gate that trips fails the build. `nix build .#<attribute>` builds one package.

## License

[MIT](LICENSE) © 2026 Shochraos
