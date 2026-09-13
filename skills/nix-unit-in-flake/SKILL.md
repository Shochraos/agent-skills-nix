---
name: nix-unit-in-flake
description: "Use when adding a nix-unit test suite to a flake-parts Nix repo or debugging nix-unit in a derivation — covers the path/interpolation traps, the test-attrset shape, expectedError matching, evaluating module-system contracts with lib.evalModules, and which contracts are worth testing at all"
---

# nix-unit in a flake-parts repo

Wiring a `nix-unit` suite into a flake-parts project, with the traps that each cost a rebuild when missed.

## Wiring

1. Declare entries in the project's path registry — one for the test *directory*, plus one for every production file the suites import:

   ```nix
   tests = { dir = ./tests; options = ./modules/flake/options.nix; };
   helpers = { display = ./lib/display.nix; };
   ```

2. The suite aggregator (`tests/default.nix`) is a function taking `nixpkgsPath` and those production paths, and it evaluates to the test attrset itself:

   ```nix
   { nixpkgsPath ? <nixpkgs>, optionsPath }:
   let
     pkgs = import nixpkgsPath { };
     inherit (pkgs) lib;
   in
   (import ./suite-a.nix { inherit lib optionsPath; })
   // (import ./suite-b.nix { inherit lib; })
   ```

3. Each suite imports production code from the passed store path: `import optionsPath { inherit lib; }`.

4. The check, inside `perSystem` (no new flake input — `pkgs.nix-unit` ships in nixpkgs):

   ```nix
   checks.unit-tests = pkgs.runCommandLocal "nix-unit-suite" {
     nativeBuildInputs = [ pkgs.nix-unit ];
   } ''
     export HOME="$TMPDIR"
     nix-unit --eval-store "$HOME" \
       --argstr nixpkgsPath ${pkgs.path} \
       --argstr optionsPath ${tests.options} \
       ${tests.dir}/default.nix
     touch $out
   '';
   ```

   Inside a flake-parts module that must reach flake outputs from `perSystem`, bind the module argument list with `top@{ config, ... }` — flake-parts deliberately does not alias top-level names inside `perSystem`, and `throwAliasError` will tell you so.

## Traps

- **Interpolate the directory, not the file.** `${someFile}` copies that file alone into the store, so `./sibling.nix` inside it resolves to `/nix/store/sibling.nix`. Use `${dir}/default.nix`.
- **Never name the aggregator's key `tests`** or anything `test`-prefixed: nix-unit reads a `test` prefix as a case and fails with `Missing attrset key 'expr'`. Non-`test` keys are recursed into; the file must evaluate to the attrset directly.
- **The store copy is the test directory in isolation**, so `../modules/...` resolves to `/nix/store/modules/...`. Pass production files in as arguments.
- **Each `--argstr` must match a declared parameter**; add them as suites need them.
- **`expectedError.type` is unreliable for module-system assertions.** A violated option type reports `ThrownError`, not `TypeError`, because the module system `throw`s. Match `expectedError.msg`, which is a regex.
- **Never deep-force a derivation in `expr`/`expected`** — compare `${drv}` strings, or you get a stack overflow.
- **Prove the wiring fails.** Attribute every mutation to exactly one case, and read the log (`--print-build-logs`, or `nix log <drv>`) — `nix build` prints only a five-line tail.

## Testing module-system contracts

Evaluate the declarations with `lib.evalModules`, supplying stubs for the module's file-level arguments and an explicit `options.` declaration for anything the module reads back. A module cannot mix top-level `options` with top-level config attributes — split them into separate modules.

## What is worth testing

A gate that evaluates NixOS `assertions` already proves today's config is valid, and `nix flake check` does force them. That is an *instance* check and cannot prove a guard *rejects* bad input, because feeding the real config bad input breaks the build by design. Write tests for rejection branches and for values a build cannot see (derived tables, merges that silently drop keys), never for declarative data or anything the build already forces. Test the code the shipped module actually runs — extract it into a library file consumed by both the aspect and the test rather than re-implementing it in the test.
