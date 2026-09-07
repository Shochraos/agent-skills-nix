---
name: omp-project-migration
description: "Migrate omp per-project state (memory bank, sessions, history) after moving a repository to a new path"
---

# omp project migration (repo moved to a new absolute path)

omp keys per-project state by absolute cwd. After `mv <repo> <newpath>`:

## 1. Stop omp
No omp session may be running with cwd inside the repo (WAL contention on the bank DB).

## 2. Memory bank
Bank dir: `~/.omp/agent/memories/mnemopi/banks/<bank>/mnemopi.db`.
Bank name = `sanitize(basename(newpath)) + "-" + Bun.hash(newpath).toString(36)`
(Bun.hash = wyhash64, unpadded base36; sanitize = non-alphanumeric -> `-`).
Verify against existing banks before trusting a hand computation; or use the
create-then-replace alternative: start omp once in the new path, quit, then copy
the old bank's `mnemopi.db` over the freshly created one.

Then rename/copy the bank dir to the new name AND update the rows:

```sql
UPDATE working_memory  SET session_id = '<newbank>';
UPDATE facts           SET session_id = '<newbank>';
UPDATE memoria_facts   SET session_id = '<newbank>';
-- plus any other table with a session_id column that holds rows
-- (enumerate with PRAGMA table_info)
```

Skipping the UPDATE is the classic failure: bank loads, retention writes land,
but recall returns empty because recall filters rows by session_id = bank name.
Verified both directions 2026-08-28 (omp 18.0.6).

## 3. Sessions
`~/.omp/agent/sessions/<encoded-cwd>/` where encoded-cwd is the absolute path
with `/` -> `-` MINUS the `/home/<user>` prefix (e.g.
`/home/shochraos/Repositories/nix/agent-skills-nix` -> `-Repositories-nix-agent-skills-nix`).
After the move confirm old sessions appear in `omp --resume` picker.

## 4. Prompt history
`~/.omp/agent/history.db` table `history` has a `cwd` column queried with a cwd
filter:

```sql
UPDATE history SET cwd = '<newpath>' WHERE cwd = '<oldpath>';
```

## 5. Threads (optional)
`~/.omp/agent/agent.db` table `threads` (cwd, rollout_path) — usually few rows,
stage1 system, safe to update or ignore.

## Verification
From the new path, print-mode probe asking the agent to call `recall` on a query
with known bank hits and quote raw ids. Model-narrated probes of injected
blocks are unreliable; tool-result output is machine-verifiable.

## 6. TTL hazard — the verification probe can wipe a stale bank
mnemopi's compiled defaults (`workingMemoryLimit: 1000`, `workingMemoryTtlHours: 24`,
read from the omp binary) make every bank a 24-hour rolling window: on session
activity, rows older than the TTL are pruned and a cascade (`source_msg_id` /
`source_memory_id`) deletes their derived facts, memoria_facts, annotations and
embeddings. A bank idle longer than the TTL is therefore wiped BY THE PROBE
ITSELF (happened 2026-09-04: 87 rows lost). Before probing, check the bank's
newest row (`SELECT MAX(timestamp) FROM working_memory`): if it is older than
the TTL, skip the probe until `mnemopi.workingMemoryTtlHours` and
`mnemopi.workingMemoryLimit` are raised in the omp config, or accept the loss
knowingly.

Recovery if pruned: retain items survive verbatim in the session transcripts
(`toolResult` records carrying `details.xdev.args.items`), fact rows often
survive in freed SQLite pages (carve with the old bank name as anchor), and the
probe's own transcript echoes its recall result with ids. After any direct
INSERT, dedupe `fts_working`/`fts_working_content` to one row per id and run
`INSERT INTO fts_working(fts_working) VALUES('rebuild')`.

## Unaffected
memory_embeddings (id-keyed), session_titles (uuid-keyed), blobs/, models.db,
`~/.omp/agent/cache/`, project `.omp/` files (move with the repo).
