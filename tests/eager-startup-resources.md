# Eager startup trial — initial live resource observation

2026-10-28, 17:11:11–17:12:11 CET. User-authorized, read-only observation of the
already-running desktop services. **Not a fresh-login, controlled-idle, cold-start,
performance-regression or matched-release benchmark.** No service was started,
stopped, restarted or reconfigured and no domain RPC was submitted.

The existing independently managed services already implement the
[selected eager-startup trial](../contracts/eager-startup-trial.md), including
Applications. Effective `WantedBy`/`PartOf`, enabled links and deployment ownership
were inspected. All five daemon main PIDs and cgroups stayed stable during sampling,
with no recorded automatic restarts. Their start timestamps were 15:17:54–55 CET,
well before this observation. A new login was not performed.

## Results

Seven samples, ten seconds apart, approximately 60 seconds elapsed. CPU is the
cgroup CPU-time delta divided by elapsed monotonic time; **100% means one CPU core**,
not the whole machine. PSS is proportional resident memory summed over service
processes (including cgroup descendants); table memory is the sampled maximum.
Missing metrics would be unavailable, not zero; all listed measurements succeeded.

| Service | Average CPU, one core | Peak PSS, MiB | Peak cgroup memory, MiB |
| --- | ---: | ---: | ---: |
| Applications | 4.289% | 66.31 | 222.91 |
| Bar | 1.642% | 129.01 | 98.07 |
| Bluetooth | 0.132% | 22.76 | 13.52 |
| Clipboard facade | 0.162% | 61.57 | 54.48 |
| Networking | 0.369% | 21.66 | 14.74 |
| Clipboard engine / Ringboard server | 0.000% rounded | 1.04 | 8.68 |

Total observed CPU: **6.594% of one core**. Peak aggregate PSS across corresponding
sampling rounds: **302.35 MiB**. Per-unit peaks need not occur in the same round.
The engine's measured CPU increment rounded to zero, not a general zero-cost claim.

Cgroup memory and PSS are different accounting scopes and must not be added.
Cgroups charge file cache and kernel allocations, and shared pages need not be
charged to the same cgroup whose processes map them. Applications' sampled cgroup
file charge was about 107.95 MiB and anonymous charge 58.02 MiB; its 222.91 MiB
cgroup total is not its proportional process footprint. PSS itself is not private
heap, an allocation profile or a measurement of startup cost.

This excludes Shelllist/Quickshell, system NetworkManager/BlueZ/PipeWire, player
applications and other shared desktop services. The independently running clipboard
engine is included explicitly. No attempt was made to stop user activity, change
which panels were open or alter sampling performed by the Applications daemon.
The main follow-up is Applications' background CPU, rather than assuming eager
residency is free. The observed sample does not identify its cause.

## Reproduction and evidence

A bounded standard-library Python sampler read only:

- `systemctl --user show` service identity/state/enablement before and after;
- service-cgroup `cpu.stat`, `memory.current`, `memory.stat` and descendant
  `cgroup.procs`;
- each member's `/proc/<pid>/smaps_rollup` RSS/PSS.

Sampling held the shared orchestration check lock to exclude cooperating heavy
checks. It read the authorized live service metadata rather than using an isolated
fake-service test environment. No command lines, application titles, clipboard
contents, credentials or domain responses were collected. Host activity and
non-cooperating workloads were not controlled.

Raw observations and the exact read-only sampler are retained at:

```text
/home/laufan/Projects/shelllist-orchestration/20261027T203355Z/tasks/coordinator-eager-startup/
  sample.py
  resources.json
```

Exact invocation:

```sh
timeout 100 flock --exclusive --timeout 20 \
  /home/laufan/Projects/shelllist-orchestration/checks.lock \
  python3 /home/laufan/Projects/shelllist-orchestration/20261027T203355Z/tasks/coordinator-eager-startup/sample.py \
  > /home/laufan/Projects/shelllist-orchestration/20261027T203355Z/tasks/coordinator-eager-startup/resources.json
```

Further samples should use a new output file to retain this baseline. No persistent
monitor or timer was installed. Cold-login resource peaks, long-term growth and
comparative on-demand/eager cost remain unmeasured.
