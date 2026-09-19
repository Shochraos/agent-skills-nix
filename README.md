# agent-skills-nix

The agent skills behind [nixfiles](https://github.com/Shochraos/nixfiles), packaged as Nix derivations and kept fresh by a weekly auto-updater — plus one runtime package: a fully declarative Scrapling MCP server.

> **AI disclaimer:** The Nix packaging, the auto-update workflow and this README were written with AI assistance. Skill content comes from the upstream repositories listed below — except the `managed-skills` payload, which is self-authored. The packaging only rewrites paths and commands inside the upstream skills so their internal references resolve under oh-my-pi's `skill://` scheme, and it fails the build when upstream drift breaks that contract. Read what you install.

## What it packages

| Package | Upstream source | Skills | Per-skill attributes |
| --- | --- | --- | --- |
| `superpowers-skills` | [obra/superpowers](https://github.com/obra/superpowers) | 11 | `superpowers-<skill-name>` |
| `vendored-skills` | [marceloeatworld/nixos-ai-skill](https://github.com/marceloeatworld/nixos-ai-skill), [TheQtCompanyRnD/agent-skills](https://github.com/TheQtCompanyRnD/agent-skills), [vercel-labs/skills](https://github.com/vercel-labs/skills), [wshobson/agents](https://github.com/wshobson/agents), [anthropics/skills](https://github.com/anthropics/skills), one file from [github/awesome-copilot](https://github.com/github/awesome-copilot) | 29 | `vendored-<skill-name>` |
| `managed-skills` | self-authored — promoted from oh-my-pi's `~/.omp/agent/managed-skills/`, source lives in this repo's `skills/` tree | 9 | `managed-<skill-name>` |

The three payloads are deliberately separate derivations — needle edits, `sed` rewrites and verbatim copies respectively — sharing nothing but the `package.nix` shape. Every skill is also packaged on its own, as `packages.<system>.<source>-<skill-name>`: 49 attributes in total, so a consumer installs exactly the skills it wants instead of a whole payload. Each of those is one directory copied out of its gated payload, so it is byte-identical to that skill inside the aggregate and its closure is only its own store path.

There is no `default` package — `nix build` always names an attribute.

`scrapling-runtime` is a fourth package, deliberately not a payload: it is not a skills directory, so it has no per-skill attributes. It builds a python package set (scrapling 0.4.15, mcp 2.x, patchright from the PyPI wheel — the GitHub source is not the release content) on top of nixpkgs Chromium. Its `bin/scrapling-mcp` wrapper pins the browser (`SCRAPLING_EXECUTABLE_PATH`) and the node driver binary (`PLAYWRIGHT_NODEJS_PATH`), so no FHS-linked binary ever execs: no pip venv, no browser cache, no nix-ld, no steam-run.

## How it works

- `superpowers-skills` edits upstream with literal `--replace-fail` needles (upstream rewording one of them is a build error, not silent rot) and ends with a banned-pattern gate that greps the payload for content that must never reach an agent (git write commands, hand-rolled install instructions, disabled-skill handoffs).
- `vendored-skills` edits a fast-moving upstream with `sed` rewrites (a literal needle would break on every daily doc refresh) and runs three gates: banned patterns in `*.md`, stricter banned patterns in `SKILL.md` only, and a resolution gate that walks every `skill://` token in the payload and fails if it does not name a skill that exists. Its copies and its per-skill edits are evaluation-visible data, and both the build script and the per-skill package list are generated from it, so a skill cannot be copied without becoming selectable, or selectable without being copied.
- `managed-skills` copies the self-authored `skills/` tree verbatim — no upstream input, no rewrites — and runs the same gate set as `vendored-skills`. Promotion means copying a skill out of oh-my-pi's `~/.omp/agent/managed-skills/`; the managed copy is deleted once the payload is live.
- Each per-skill package is sliced out of its gated payload with `cp -r`, so the payload's gates run for any slice you build and the slice stays byte-identical to that skill directory. Eval-time guards fail the flake if a per-skill name would shadow a payload name, or if fewer skills were generated than the payloads report. `lib.<system>.mkSkillset [ … ]` joins a chosen set into one skills directory and rejects an unknown name, quoting the names that exist.
- `scrapling-runtime` overrides a scoped python package set: mcp 2.1.1 (scrapling imports a 2.x-only API), mcp-types, patchright 1.62.2, and small bumps scrapling's runtime-deps check enforces (cssselect, curl-cffi). nixpkgs' playwright 1.61 driver is kept and works through `executable_path`; that compat is proven by the smoke test, not assumed.
- `checks.<system>` carries the packages, so `nix flake check` actually builds every package — payloads through their gates, the runtime through its own build — instead of just evaluating them. The auto-updater relies on this: a red run means nothing lands.
- The six skill sources are flake inputs; the lock is bumped by the workflow, not by hand.
- The `create-readme` skill is a `fetchurl` pinned to a commit sha inside `pkgs/vendored-skills/package.nix`. `nix flake update` can never move it; a refresh means editing the rev and its hash together.

### Auto-update

Every Monday 06:00 UTC (and on manual dispatch), the `update-skill-sources` workflow bumps the six skill inputs, runs `nix flake check`, and pushes `flake.lock` only when the build is green and the lock actually changed. nixpkgs is deliberately not auto-bumped, so the lock diff stays focused on skills. If a gate trips, the run is red and consumers keep building the last pinned rev.
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
    "${inputs.agent-skills-nix.packages.${pkgs.stdenv.hostPlatform.system}.managed-skills}"
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
    "managed-nix-unit-in-flake"
  ]}"
];
```

`mkSkillset` joins the named per-skill packages into one directory and fails evaluation on a name that does not exist, printing the names that do. Selecting a skill on its own leaves any reference it makes to a sibling skill (`skill://<name>`, or `superpowers:<name>`) pointing at a skill you did not install: the resolution gate checks the payload, not your selection. Pick related skills together.

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
pkgs/superpowers-skills/package.nix   the needle-edited payload
pkgs/vendored-skills/package.nix      the sed-edited payload
pkgs/managed-skills/package.nix       the verbatim self-authored payload
pkgs/managed-skills/gates.nix         the gates the managed payload runs
skills/                               the self-authored sources it packages
pkgs/scrapling-runtime/               the Scrapling MCP runtime + wrapper
.github/workflows/update-skill-sources.yml   the weekly auto-updater
.github/workflows/build-packages.yml   the per-commit build gate
```

## Development

`nix develop` provides `nixfmt` and `nixd`. `nix fmt` formats. `nix flake check` is the gate: `checks.<system>` carries every package plus a smoke test of `mkSkillset`, and each payload and per-skill derivation is a `runCommandLocal` whose build script runs the banned-pattern and `skill://` resolution gates, so a failed gate fails the build. `nix build .#<attribute>` builds one package.

## License

[MIT](LICENSE) © 2026 Shochraos
