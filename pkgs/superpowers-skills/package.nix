{
  lib,
  runCommandLocal,
  src,
}:
let
  version = (builtins.fromJSON (builtins.readFile "${src}/package.json")).version;

  droppedSkills = [
    "subagent-driven-development"
    "finishing-a-development-branch"
    "using-superpowers"
  ];

  allSkills = import ../lib/dir-skills.nix { inherit lib; } "${src}/skills";

  rewrites = {
    "brainstorming/SKILL.md" = [
      {
        from = "6. **Write design doc** — save to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit";
        to = "6. **Write design doc** — save to `.omp/<TOPIC>-PLAN.md` at the repository root";
      }
      {
        from = "- Write the validated design (spec) to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`";
        to = "- Write the validated design (spec) to `.omp/<TOPIC>-PLAN.md` at the repository root";
      }
      {
        from = "- Commit the design document to git";
        to = "- Leave the design document uncommitted";
      }
      {
        from = "Spec written and committed to";
        to = "Spec written to";
      }
      {
        from = "`skills/brainstorming/visual-companion.md`";
        to = "`skill://brainstorming/visual-companion.md`";
      }
    ];

    "brainstorming/spec-document-reviewer-prompt.md" = [
      {
        from = "**Dispatch after:** Spec document is written to docs/superpowers/specs/";
        to = "**Dispatch after:** Spec document is written to `.omp/<TOPIC>-PLAN.md`";
      }
    ];

    "diagnosing-superpowers/prompts/plan-adherence.md" = [
      {
        from = "\"Plan\" here means any agreed course of action, not git commits.";
        to = "\"Plan\" here means any agreed course of action, not commits.";
      }
    ];

    "diagnosing-superpowers/prompts/quality-evidence.md" = [
      {
        from = "every `git commit` with its message";
        to = "every commit with its message";
      }
    ];

    "executing-plans/SKILL.md" = [
      {
        from = "- Your harness has no subagent tool (see the per-platform references in\n  `../using-superpowers/references/`). Never fabricate a dispatch; run\n  the plan here.";
        to = "- Your harness has no subagent tool. Never fabricate a dispatch; run\n  the plan here.";
      }
      {
        from = "- Tasks are mostly independent — the same precondition as\n  superpowers:subagent-driven-development.";
        to = "- Tasks are mostly independent.";
      }
      {
        from = "Prefer superpowers:subagent-driven-development when your human partner\nwants a review gate on every task, or when the plan is long enough that\nits later tasks would run on a compacted context.";
        to = "Prefer dispatching a fresh subagent per task when your human partner\nwants a review gate on every task, or when the plan is long enough that\nits later tasks would run on a compacted context.";
      }
      {
        from = "Ensure the work happens in an isolated workspace: use\nsuperpowers:using-git-worktrees to create one or verify the existing one.\nNever start implementation on a main/master branch without your human\npartner's explicit consent.";
        to = "Work in the current checkout. A worktree is opt-in: use\nsuperpowers:using-git-worktrees only when your human partner asks for\none.";
      }
      {
        from = "The workspace and ledger are shared with superpowers:subagent-driven-development\n— same directory, same format — so a plan can change executors mid-flight\nand the new one resumes from the same ledger.";
        to = "The ledger is shared between executors — same directory, same format —\nso a plan can change executors mid-flight and the new one resumes from\nthe same ledger.";
      }
      {
        from = "- Each plan owns a workspace: at skill start, run\n  `../subagent-driven-development/scripts/sdd-workspace PLAN_FILE` — it\n  prints the plan's git-ignored directory";
        to = "- Each plan owns a workspace: at skill start, create\n  the plan's git-ignored directory";
      }
      {
        from = "Run `../subagent-driven-development/scripts/review-package PLAN_FILE MERGE_BASE HEAD`\n(MERGE_BASE = the commit the branch started from, e.g.\n`git merge-base main HEAD`) and review from the file it prints.";
        to = "Assemble a review package for the plan — the diff against MERGE_BASE\n(MERGE_BASE = the commit the branch started from, e.g.\n`git merge-base main HEAD`) — and review from it.";
      }
      {
        from = "\"Use superpowers:finishing-a-development-branch\" [shape=box style=filled fillcolor=lightgreen];";
        to = "\"Report the result to the user\" [shape=box style=filled fillcolor=lightgreen];";
      }
      {
        from = "\"Final review clean: delete this plan's workspace\" -> \"Use superpowers:finishing-a-development-branch\";";
        to = "\"Final review clean: delete this plan's workspace\" -> \"Report the result to the user\";";
      }
      {
        from = "Use superpowers:finishing-a-development-branch.";
        to = "Run the verification gate for this project, retain what was learned, then report the diff. Leave integration to the user.";
      }
      {
        from = "[Read plan once: docs/superpowers/plans/feature-plan.md; spec read]\n[Resolve workspace: sdd-workspace docs/superpowers/plans/feature-plan.md — no ledger inside, fresh start]";
        to = "[Read plan once: .omp/FEATURE-PLAN.md; spec read]\n[Resolve workspace: create the .omp plan workspace — no ledger inside, fresh start]";
      }
      {
        from = "[After all tasks: review-package plan MERGE_BASE HEAD; dispatch code-reviewer, most capable model]";
        to = "[After all tasks: assemble the review package; dispatch code-reviewer, most capable model]";
      }
      {
        from = "Using superpowers:finishing-a-development-branch.";
        to = "Reporting the result to the user.";
      }
      {
        from = "\"task-start: brief + BASE; read the brief\"";
        to = "\"Take the task: read the brief; record BASE\"";
      }
      {
        from = "- Run this skill's `scripts/task-start PLAN_FILE N`. It prints the brief\n  path and BASE (the commit the task's range is cut from) in one call.\n  Read the brief for every task, including ones you remember from setup:\n  what you remember is a summary, the brief has the exact values,\n  signatures, and test cases.";
        to = "- Read the task's brief — the task's own text in the plan — for every\n  task, including ones you remember from setup: what you remember is a\n  summary, the brief has the exact values, signatures, and test cases.\n  Record BASE, the commit the task's range is cut from.";
      }
      {
        from = "[task-start plan 1 → brief read; BASE a1b2c3d]";
        to = "[Task 1 taken: brief read; BASE a1b2c3d]";
      }
      {
        from = "[task-start plan 2 → brief read; BASE d4e5f6a]";
        to = "[Task 2 taken: brief read; BASE d4e5f6a]";
      }
      {
        from = "\"Commit as the plan's commit steps say\"";
        to = "\"Report the result as the plan's steps say\"";
      }
      {
        from = "Commit as the plan's commit steps say. A task that spans several commits\nis fine; BASE is what the review range is cut from, never `HEAD~1`.";
        to = "Report the result as the plan's steps say. Committing is your human\npartner's call; BASE is what the review range is cut from, never `HEAD~1`.";
      }
      {
        from = "\"Setup: worktree, workspace + ledger, read plan + spec, pre-flight scan\"";
        to = "\"Setup: workspace + ledger, read plan + spec, pre-flight scan\"";
      }
      {
        from = "[Setup: worktree verified]";
        to = "[Setup: working in the current checkout]";
      }
    ];

    "executing-plans/scripts/task-done" = [
      {
        from = "#   BASE is the SHA task-start printed; the completion line records BASE..HEAD.";
        to = "#   BASE is the task's starting SHA; the completion line records BASE..HEAD.";
      }
      {
        from = "sdd=\"$(cd \"$(dirname \"$0\")/../../subagent-driven-development/scripts\" && pwd)\"";
        to = "dir=\"$(git rev-parse --show-toplevel)/.superpowers/sdd/$(basename \"$plan\" .md)\"";
      }
      {
        from = "dir=$(\"$sdd/sdd-workspace\" \"$plan\")";
        to = "mkdir -p \"$dir\"\necho '*' > \"$dir/.gitignore\"";
      }
    ];

    "requesting-code-review/SKILL.md" = [
      {
        from = "  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md";
        to = "  PLAN_OR_REQUIREMENTS: Task 2 from .omp/DEPLOYMENT-PLAN.md";
      }
    ];

    "using-git-worktrees/SKILL.md" = [
      {
        from = "**If NOT ignored:** Add to .gitignore, commit the change, then proceed.";
        to = "**If NOT ignored:** Add to .gitignore and tell the user. Do not commit.";
      }
    ];

    "writing-plans/SKILL.md" = [
      {
        from = "**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`";
        to = "**Save plans to:** the same `.omp/<TOPIC>-PLAN.md` file that holds the spec";
      }
      {
        from = "> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.";
        to = "> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, dispatching independent slices with superpowers:dispatching-parallel-agents.";
      }
      {
        from = ''- "Commit" - step'';
        to = "- (no commit step)";
      }
      {
        from = ''
          - [ ] **Step 5: Commit**

          ```bash
          git add tests/path/test.py src/path/file.py
          git commit -m "feat: add specific feature"
          ```'';
        to = "- [ ] **Step 5: Report the change to the user (no commit)**";
      }
      {
        from = "**\"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Please review the plan. Which execution approach would you prefer?**";
        to = "**\"Plan complete and saved to the plan file. Please review the plan. Which execution approach would you prefer?**";
      }
      {
        from = "**\"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Please review the plan. Does it capture what you want?\"**";
        to = "**\"Plan complete and saved to the plan file. Please review the plan. Does it capture what you want?\"**";
      }
      {
        from = "- **Subagent-driven** - A fresh subagent implements each task and a fresh reviewer checks it before the next one starts, then a whole-branch review at the end. Most thorough; costs a fresh context per task and per review.";
        to = "- **Parallel** - Independent slices dispatched concurrently with the native task tool, one fresh subagent per slice, then a whole-branch review at the end. Most thorough; costs a fresh context per slice and per review.";
      }
      {
        from = "**If Subagent-driven chosen:**\n- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development";
        to = "**If Parallel chosen:**\n- **REQUIRED SUB-SKILL:** Use superpowers:dispatching-parallel-agents";
      }
    ];

    "writing-skills/SKILL.md" = [
      {
        from = "**Personal skills live in your runtime's skills directory** (`~/.claude/skills/` on Claude Code) — see [codex-tools.md](../using-superpowers/references/codex-tools.md) or [gemini-tools.md](../using-superpowers/references/gemini-tools.md) for the path on those runtimes. Codex, Copilot CLI, and Gemini CLI all also recognize `~/.agents/skills/` as a cross-runtime alias.";
        to = "**Personal skills live in your runtime's skills directory** (`~/.omp/agent/skills/` for omp; `~/.omp/agent/managed-skills/` for skills the agent mints itself).";
      }
      {
        from = "- [ ] Commit skill to git and push to your fork (if configured)";
        to = "- [ ] Report the new skill to the user; leave committing to them";
      }
    ];

    "writing-skills/render-graphs.js" = [
      {
        from = "    console.error('  ./render-graphs.js ../subagent-driven-development');\n    console.error('  ./render-graphs.js ../subagent-driven-development --combine');";
        to = "    console.error('  ./render-graphs.js ../some-skill');\n    console.error('  ./render-graphs.js ../some-skill --combine');";
      }
    ];
  };

  banned = [
    "docs/superpowers"
    "skills/brainstorming/"
    "superpowers:subagent-driven-development"
    "superpowers:finishing-a-development-branch"
    "subagent-driven-development"
    "using-superpowers"
    "finishing-a-development-branch"
    "git add"
    "git commit"
    "git push"
  ];

  applyRewrites = lib.concatLines (
    lib.mapAttrsToList (
      file: subs:
      lib.concatStringsSep " \\\n" (
        [ "substituteInPlace $out/${file}" ]
        ++ map (s: "  --replace-fail ${lib.escapeShellArg s.from} ${lib.escapeShellArg s.to}") subs
      )
    ) rewrites
  );
in
{
  payload =
    runCommandLocal "superpowers-skills-${version}"
      {
        meta = {
          description = "Superpowers agent skills, with the git-integration steps removed";
          homepage = "https://github.com/obra/superpowers";
          license = lib.licenses.mit;
          platforms = lib.platforms.all;
        };
      }
      ''
        cp -r ${src}/skills $out
        chmod -R u+w $out
        rm -rf ${lib.concatMapStringsSep " " (name: "$out/${name}") droppedSkills}
        rm $out/executing-plans/scripts/task-start

        ${applyRewrites}

        for pattern in ${lib.escapeShellArgs banned}; do
          if grep -rnF --include='*.md' -- "$pattern" $out; then
            echo "superpowers-skills: upstream reintroduced '$pattern' at the sites above" >&2
            exit 1
          fi
        done

        for name in subagent-driven-development using-superpowers finishing-a-development-branch; do
          if grep -rnF -- "$name" $out; then
            echo "superpowers-skills: '$name' outside *.md at the sites above" >&2
            exit 1
          fi
        done
      '';

  skillNames = builtins.attrNames (builtins.removeAttrs allSkills droppedSkills);
}
