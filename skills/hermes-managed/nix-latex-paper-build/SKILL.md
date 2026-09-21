---
name: nix-latex-paper-build
description: |
  Use when scaffolding or building a LaTeX paper with nix.
---

# Nix-built LaTeX papers

One repo per paper under `~/Repositories/teX/<name>/`: LaTeX sources plus a
flake that turns them into a PDF with `nix build`. Sibling repos
(`minerva-paper`, `HALO-paper-1`, `cv`) share one flake shape — match it rather
than inventing a new one.

## Resolve the target directory before writing anything

A "create the groundwork for a paper" request rarely names a path, and the
session CWD is often `$HOME` — scaffolding there buries a project in the home
directory, and it has to be moved by hand afterwards.

1. Search for the intended project dir first: `find ~ -maxdepth 4 -type d
   -iname '*<topic>*' -not -path '*/.cache/*'`.
2. Found and non-empty → confirm before overwriting; count what is there
   (`find . -type f -not -path './.git/*' | wc -l`).
3. Nothing found, or several candidates → ask which directory. Never default to
   the CWD.

## The flake

Start from `templates/flake.nix` and change `pname`/`description`. The parts
that are house convention, not taste:

- `pkgs.texliveFull` — the top-level scheme attr. Do **not** use
  `texlive.combined.scheme-full` on current nixpkgs: it evaluates with a
  deprecation warning and is removed in 27.05. An `or`-chain fallback for older
  nixpkgs is fine, but put `texliveFull` first.
- `src = builtins.path { path = ./.; filter = ... }` excluding `.git`, `.omp`,
  `.direnv` and anything prefixed `result`. Without the filter every build
  copies the VCS and editor state into the store and rehashes the source.
- `latexmk -pdf -bibtex -interaction=nonstopmode -halt-on-error main.tex`, with
  `export HOME=$TMPDIR` and `export TEXMFVAR=$TMPDIR/texmf-var` first — the
  sandbox has no writable home, and without `TEXMFVAR` font and map generation
  fails.
- Output at `$out/main.pdf`, not `$out/share/.../main.pdf`.
- `devShells.default` carrying the same `texliveFull`, for `latexmk -pvc`
  iteration.
- `formatter = pkgs.nixfmt-tree`.

## Layout

`main.tex` (document shell: class options, title/author, abstract, keywords,
`\input` order, `\bibliographystyle`) + `preamble.tex` (packages) +
`sections/NN-name.tex` (one file per section, numbered so `ls` order matches
the paper) + `references.bib` + `figures/`.

Preamble load order: `babel` → content packages → `hyperref` → `cleveref`
**absolutely last** (it must see the final counters and reference names).

IEEEtran: `\documentclass[10pt,journal]{IEEEtran}` for two-column, `[conference]`
for the conference format. `IEEEtran.bst` is plain BibTeX — no natbib, so
`\citet`/`\citep` are undefined; use `\cite`.

## Verify the build before claiming it

`nix build` exiting 0 is necessary, not sufficient — a paper can build and still
carry unresolved references. Then:

1. Extract the PDF text (`read_file` on `result/main.pdf` auto-extracts the text
   layer) and confirm every section heading, every `\cref` target, and every
   citation resolved to a number.
2. Check the log for residue: `nix log $(readlink result).drv | grep -cE
   'undefined|Warning: Citation'` must be 0.
3. Test a `src` filter by planting the excluded dirs and comparing
   `nix eval .#packages.<system>.default.src` before and after — the store path
   must not change. Do this in a `/tmp` copy, never in the live repo.

## LaTeX pitfalls that cost a build cycle

- **`\cref` inside a `\todo[inline]{...}` argument is fatal**: cleveref and
  todonotes clash in that argument and pdflatex dies with `Argument of
  \@cref@stack@top has an extra }`, all references unresolved afterwards.
  Refer to the label in prose inside todo notes instead.
- **A bare `\cref` with no brace argument** swallows the next token: the log
  shows ``Reference `.' undefined`` and a period disappears. Give it an
  argument, or write "cross-reference" as a word.
- **Instructional prose that mentions a citation command** (`Cite with
  \cite{key}...`) really cites that key and renders `[?]` with an
  unresolved-citation warning. Write it as `\texttt` or rephrase without the
  command.
- Placeholder `.bib` entries are worth including deliberately: one obviously
  fake entry exercises the citation path so a broken bibliography surfaces at
  scaffold time rather than at submission.

## Git caveat: `nix build` compiles the committed tree

Once the repo exists, Nix self-fetches through git, so `builtins.path
{ path = ./.; }` resolves against the **committed** tree. Uncommitted `.tex`
edits never reach the build, and the only signal is
`warning: Git tree ... is dirty` on stderr. Commit before building, or iterate
with `latexmk` in the dev shell. A half-created `.git` directory (e.g. one made
to test a filter) is worse than none: self-fetch switches to `git+file://` and
fails outright. Put this in the repo README — it is the first surprise anyone
running `git init` will meet.
