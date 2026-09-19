---
name: steam-launch-env-diagnosis
description: "Use when a Steam game, non-Steam shortcut, or launch-option wrapper (PROTON_*, mangohud, gamemoderun, hdr, gamescope, a shell script, any Nix-wrapped tool) dies instantly with exit 127 OR exit 1, or fails only under a launch option while working from a terminal. Covers the launch child's sanitized LD_LIBRARY_PATH/SYSTEM_LD_LIBRARY_PATH scrub, library SHADOWING by Steam's 2019 steam-runtime (libattr ATTR_1.3, libgcc_s, libstdc++), LD_PRELOAD overlay dependency resolution and the $ORIGIN no-restart fix, systemd scope-vs-service env inheritance, non-Steam-shortcut appids, and capturing the real launch environment."
---

# Diagnosing a Steam launch option that dies (exit 127, exit 1, and friends)

A launch option can work perfectly in a terminal and still die in Steam. The
cause is almost always that **the launch child's environment is not Steam's
own environment**, and neither is your login shell's.

## The trap

`steam.sh` snapshots the session library path at Steam *startup*:

```sh
export SYSTEM_LD_LIBRARY_PATH="${LD_LIBRARY_PATH-}"   # steam.sh:136
```

The launch child inherits `SYSTEM_LD_LIBRARY_PATH`, **not** the richer
`LD_LIBRARY_PATH` the running Steam process itself carries (which on a
NixOS/Nix host typically does include `/run/opengl-driver/lib`). On this
machine the live values were:

| variable | value |
|---|---|
| Steam's own `LD_LIBRARY_PATH` | 16 entries, `/run/opengl-driver/lib` at position 8, `-32/lib` at 9 |
| `SYSTEM_LD_LIBRARY_PATH` (= what the launch gets) | `/etc/sane-libs` only |

So "it runs fine when I execute it" is not evidence about the launch path.

## Step 1 — read the failure correctly

Exit **127** with a line like

```
/nix/store/…-bash-5.3p15/bin/bash: error while loading shared libraries: libGL.so.1: cannot open shared object file
```

is **not** a syntax error in your launch option and **not** specific to your
tool. That bash is the *shebang interpreter* of a Nix-wrapped program, so the
program never ran; and because Steam execs the option through `sh -c`, the
shell's death takes the whole launch with it (no Proton process spawns).

Cross-check `~/.local/share/Steam/logs/gameprocess_log.txt`: the tracked-process
line names the whole command, and `no longer tracking PID …, exit code 127`
gives the real status. Correlate `hdr`-present launches against exit codes in
`console-linux.txt` — if every 127 carries your wrapper and none of the others
do, the failure follows the *program*, not the title.

## Step 2 — the overlay is usually the dependency

Steam injects `LD_PRELOAD=…/ubuntu12_{32,64}/gameoverlayrenderer.so`. That
shared object has `NEEDED libGL.so.1` and **no RPATH** (`RUNPATH $ORIGIN`, with
nothing beside it), so libGL can only come from `LD_LIBRARY_PATH`. Because
`LD_PRELOAD` applies to *every* subsequent dynamic ELF — including every
`#!/nix/store/…/bash` shebang — a missing libGL kills the interpreter before
your code runs.

`/etc/ld.so.cache` and the sandbox glibc caches typically contain **zero**
`libGL.so.1` entries and no driver path. Verify rather than assume:

```bash
strings /etc/ld.so.cache | grep -c 'libGL\.so\.1'      # expect 0
```

## Step 2b — the other direction: Steam's runtime can SHADOW Nix's libraries

Step 2 is about a library that is **absent**. A second, quieter failure has the
same cause and the opposite shape: the launch env's ~10 `steam-runtime`
directories are packed with **2019-era** builds, and the loader takes the first
match **by name**, so they win against the Nix store outright. Nothing is
missing; the wrong one is simply found first.

Measured on this machine from the real launch child env:

| library | Steam runtime provides | your Nix binary needs |
|---|---|---|
| `libattr.so.1` | `ATTR_1.0`–`ATTR_1.2` (2019-04-03) | `ATTR_1.3` (attr-2.6.0) |
| `libgcc_s.so.1` | too old | `GCC_12.0.0`, `GCC_13.0.0` |
| `libstdc++.so.6` | `6.0.21` (2019) | `GLIBCXX_*` |

The symptom is therefore **exit 1 (or any status), instantly**, with an error
naming a *version*, not a missing file:

```
mktemp: …/steam-runtime/lib/x86_64-linux-gnu/libattr.so.1:
        version `ATTR_1.3' not found (required by mktemp)
```

**Why it kills the whole launch:** `mktemp`, `sort`, `comm`, `cat`, `rm`,
`sleep`, `grep` and `hyprctl` all break; only `jq` and `flock` survived in
testing. A script under `set -e` dies at its **first** such command, so the
game is never spawned. Diagnose with a trace, which names the failing call:

```bash
bash -x /path/to/wrapper <child> 2>&1 | tail -20
# ++ mktemp -d
# mktemp: … version `ATTR_1.3' not found
# + state=
```

**Do not trust the absence of this error in Steam's logs.** Unlike the exit-127
case, child stderr was **not** captured anywhere under
`~/.local/share/Steam/logs/` here — the same launch showed no message at all in
`console-linux.txt`. Only `gameprocess_log.txt`'s `exit code 1` on the tracked
PID revealed it.

### The fix: sanitize for your tools, restore for the child

Repairing the path is not the answer (the collision is by name, and every
steam-runtime dir precedes the store), and neither is reordering. Keep the
wrapper's own tooling off that path entirely, and hand the child the untouched
value, which it genuinely needs for the graphics drivers:

```sh
launch_ld="${LD_LIBRARY_PATH-}"
unset LD_LIBRARY_PATH          # our own tooling: coreutils, jq, hyprctl, …

# … run the wrapper's logic and polling here …

( if [ -n "$launch_ld" ]; then export LD_LIBRARY_PATH="$launch_ld"; fi
  "$@" ) &                     # the game keeps the environment Steam gave it
```

### Regression-test without a compiler

Copy any **real** Nix ELF over the shadowing name and point the path at it:

```bash
install -m 644 "$(nix eval --raw --impure \
  --expr 'let p = import <nixpkgs> {}; in "${p.lib.getLib p.glibc}/lib/libm.so.6"')" \
  "$scratch/libattr.so.1"
LD_LIBRARY_PATH="$scratch" mktemp -d     # must FAIL, or the harness is dead
```

An **invalid or truncated** file does **not** reproduce — the loader skips a
bad object rather than failing on a version symbol — so the copy must be a real
ELF, and the test should assert that the shadow still breaks a plain `mktemp`
before trusting any result from it. `cp` fails over a store file (mode 444);
use `install`.

## Step 3 — reproduce with the SCRUBBED value

Build the discriminator by hand. Note the 32-bit overlay is *expected* to
produce a benign `ELFCLASS32 … ignored` notice.

```bash
S=$HOME/.local/share/Steam
BAD=/etc/sane-libs                       # the scrubbed value
FIX=$BAD:/run/opengl-driver/lib:/run/opengl-driver-32/lib
B=/nix/store/…-bash-5.3p15/bin/bash      # your wrapper's shebang interpreter

env LD_LIBRARY_PATH=$BAD LD_PRELOAD="$S/ubuntu12_32/gameoverlayrenderer.so:$S/ubuntu12_64/gameoverlayrenderer.so" \
    "$B" -c 'echo STARTED'               # -> cannot open shared object file
env LD_LIBRARY_PATH=$FIX LD_PRELOAD=… "$B" -c 'echo STARTED'   # -> STARTED
```

Then run the **real** tracked-process command (copy it from
`gameprocess_log.txt`, replacing the game with `/bin/true`) under both envs.
Test *every* binary in the chain, not just your tool — `bash`, `grep`, `mv`,
`hyprctl` and `steam-launch-wrapper` itself, which is usually the next program
after your wrapper.

Watch the exit codes: `rc 255` from `steam-launch-wrapper` means the chain
loaded and the wrapper merely has no Steam context; `rc 127` is the loader
failure. Do not report 255 as a failure.

## Step 3b — the no-restart fix: satisfy `$ORIGIN` directly

**Check this first — it usually means the user needs to restart nothing.**

Both overlays carry `RUNPATH = $ORIGIN`, so the loader looks in the overlay's
own directory *before* `LD_LIBRARY_PATH`. Put libGL there:

```bash
ln -s /run/opengl-driver/lib/libGL.so.1    ~/.local/share/Steam/ubuntu12_64/libGL.so.1
ln -s /run/opengl-driver-32/lib/libGL.so.1 ~/.local/share/Steam/ubuntu12_32/libGL.so.1
```

Confirm `$ORIGIN` is really what you think, and control it both ways:

```bash
readelf -d ~/.local/share/Steam/ubuntu12_64/gameoverlayrenderer.so | grep -E 'RUNPATH|NEEDED.*libGL'
# then: full command with the links -> 255; move them away and repeat -> 127
```

This takes effect **immediately** — no reboot, relog, switch, or Steam restart —
because resolution happens per exec. Make it survive reinstall by declaring it
where the config manager owns files (in home-manager: `home.file` with
`source = config.lib.file.mkOutOfStoreSymlink "<absolute path>"` and
**`force = true`**, since a foreign pre-existing symlink is otherwise a
`checkLinkTargets` collision).

Keep the search-path fix as well: `$ORIGIN` only rescues the *overlay's*
dependency, whereas a correct `LD_LIBRARY_PATH` is what protects every other
binary in the chain.

## Step 4 — capture the real launch env (only if still unresolved)

Install a tiny shim at the **first** PATH entries that Steam's own PATH puts
ahead of your tool, writing to `$HOME`:

```sh
#!/nix/store/…-busybox-static-…/bin/sh   # STATIC, so the preload cannot kill it
{ echo "PATH=$PATH"; echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
  echo "LD_PRELOAD=$LD_PRELOAD"
  echo "SYSTEM_LD_LIBRARY_PATH=${SYSTEM_LD_LIBRARY_PATH-<unset>}"; } > "$HOME/launch-env.txt" 2>&1
exec /path/to/real/tool "$@"
```

**Never write to `/tmp`** — Steam runs under a bubblewrap sandbox with
`--tmpfs /tmp`, so your file vanishes. Write to `$HOME`.

**You cannot self-trigger a launch for a non-Steam shortcut.**
`steam -applaunch <shortcut-appid>` is a silent no-op and
`xdg-open 'steam://rungameid/<appid>'` does nothing; only pressing Play in the
Steam UI fires it. Detect this by counting `adding PID` in
`gameprocess_log.txt` before/after.

Remove the shim afterwards and verify both paths are gone.

## Step 5 — fix the search path, not the shebang

On NixOS, add the driver directories to the session (a **list**, so it
concatenates with whatever else contributes — no `mkForce`):

```nix
environment.sessionVariables.LD_LIBRARY_PATH = [
  "/run/opengl-driver/lib"
  "/run/opengl-driver-32/lib"
];
```

Before choosing a global search path, check it cannot shadow anything:

```bash
ls /run/opengl-driver/lib/ | grep -E '^(libc|libm|libpthread|libdl|libstdc\+\+|libz|libgcc|libattr|libselinux|libcap)\.' || echo none
```

Confirm the merged value renders, not just evaluates — read the built
generation's `etc/set-environment` **and** `etc/pam/environment`.

### You cannot shortcut this with `systemctl --user set-environment`

A `--scope` inherits the **caller's** env; only a `--service` inherits the user
manager's. Compositors spawn `app-<name>-<hash>.scope`, so
`systemctl --user set-environment` never reaches them and neither does
restarting the app — only a relogin does. Check before proposing a restart:

```bash
cat /proc/<pid>/cgroup          # .scope => caller env; .service => manager env
systemd-run --user --scope  printenv LD_LIBRARY_PATH   # caller's value
systemd-run --user          printenv LD_LIBRARY_PATH   # manager's value
```

## Pitfalls

- A fix proven against a synthetic reproducer is a claim about the reproducer.
  Say which half was proven where, and get the user's own confirmation for the
  end-to-end claim.
- Do not conclude that a wrapper's rc 255 is a failure: `steam-launch-wrapper`
  exits 255 outside a real Steam context. What matters is that the *loader*
  error is gone.
- Same class, other shapes: any `LD_PRELOAD` (MangoHud, extest, capture tools)
  plus a shebang wrapper is this bug. Check the preload's `NEEDED` list first.
- Restarting Steam only re-reads `SYSTEM_LD_LIBRARY_PATH` if something upstream
  of it actually changed — verify what Steam inherited (`/proc/<steam-pid>` and
  its parent chain) instead of assuming a restart picks anything up.
