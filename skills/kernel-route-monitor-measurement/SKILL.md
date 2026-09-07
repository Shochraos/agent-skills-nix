---
name: kernel-route-monitor-measurement
description: "Measuring per-netns kernel FIB events with ip -ts monitor route: flag order, ISO timestamps, buffering, clock calibration, and per-router convergence extraction"
---

# Kernel route-monitor measurement in network namespaces

Measuring per-namespace kernel FIB change events with nanosecond-order
timestamps — for convergence latency, withdrawal/re-advertisement timing,
and correctness snapshots in Mininet/netns labs.

## Starting monitors

```bash
# per netns (e.g. via mininet node.cmd): flag BEFORE subcommand in iproute2 >= 7
stdbuf -oL ip -ts monitor route > /tmp/mon_<node>.log 2>&1 &
```

Gotchas learned by debugging:
- `ip monitor route -ts` FAILS on iproute2 7.x ("Argument -ts is unknown").
  The flag is a global option: `ip -ts monitor route`.
- Redirected output is block-buffered; without `stdbuf -oL` events never
  reach the file before the process is killed.
- `-ts` prints ISO local-time `[YYYY-MM-DDTHH:MM:SS.uuuuuu]` (1 us), not
  `[sec.nsec]`. Parse with `datetime.strptime(..., "%Y-%m-%dT%H:%M:%S.%f")`
  assuming UTC, then calibrate.
- The monitor dumps existing tables (incl. `table local`) on start —
  filter `local`/`broadcast`/`anycast` and `proto kernel|boot|static`
  lines when looking for protocol-installed routes.
- Write logs OUTSIDE directories the lab recreates (Mininet's
  `initializeBGP` does `rm -rf /tmp/mn_<name>`).

## Clock calibration

Right after starting monitors, on one node:

```bash
ip route add 198.51.100.7/32 dev lo; sleep 0.3; ip route del 198.51.100.7/32 dev lo
```

Record `time.time_ns()` right after each command. Offset = wall_ns -
monitor_epoch_ns. Two events give an offset-stability check (expect
sub-microsecond agreement). All event times are then `mon_ts + offset`.

## Reading convergence out of events

- Anchor each router's protocol start to its daemon launch wall-time
  (record `time.time_ns()` around the launch call), not to process start.
- Per-router convergence = timestamp of the LAST add event of the expected
  prefix set (startup) or the LAST delete/add of the target prefix
  (withdrawal / re-advertisement). Report max/avg/p50/p95 — "last router"
  and "average router" are different numbers.
- Multipath (ECMP) adds/deletes appear as single lines with repeated
  `nexthop` tokens; match prefixes by regex `(\d+\.\d+\.\d+\.\d+)(?:/(\d+))?`
  and normalize /32 to bare IP.

## Correctness snapshot

`ip -j route show proto bgp` per namespace gives JSON routes; compare the
observed prefix set against a topology-derived expectation (loopbacks +
subnets), check ECMP by `len(route["nexthops"])`, and detect dead sessions
(a silently dead BGP session degrades ECMP to single-path while
loopback-presence checks still pass — nexthop-count checks are the
detector).
