# Agenda/Turso build-input exception

User-approved scope: only the exact `bar-daemon/Cargo.lock` rustix resolution set
`[0.38.44, 1.1.4]`. Shared direct requirement `1`, default resolution `1.1.4`,
other locks, registry/checksum checks and the checker implementation stay unchanged.
No Cargo manifest, dependency, Cargo.lock or flake.lock is changed.

The accepted Agenda dependency chain is:
`turso 0.8.0 -> turso_sdk_kit / turso_sync_sdk_kit 0.8.3`
`--build-dependency--> bindgen 0.69.5 -> which 4.4.2 -> rustix 0.38.44`.
This records the reviewed build-tool provenance of the current locked graph, not
a general permission for other rustix versions, another repository, future graph
changes, or a complete compiled feature/security audit. The exception does not
mechanically enforce dependency-edge kinds; future dependency changes need review.

Prior strict-gate failures remain valid evidence against the previous policy.
Matching source capture/preflight, unchanged-input hashes, current strict audit,
checker unit tests and negative policy probes are recorded under
`shelllist-orchestration/20261027T203355Z/tasks/coordinator-checks/rustix-exception/`.
Validation (`after.log`, frozen `check-v2.sh after` through the run's locked
`check.sh timeout 900` and matching dev shells):

- Strict audit passes: Rust 1.95.0, ten locked roots, 46 shared dependencies.
- All five build-input checker unit tests pass, including per-lock isolation and
  mandatory exception documentation. Filtered CLI tests were not executed.
- The unchanged checker rejects the captured old policy, an alternate policy
  pinning 0.38.43, and an undocumented exception. Each rejection is asserted by
  its exact diagnostic, not merely a nonzero exit.
- Policy invariants verify this is the only JSON change. Recorded Cargo manifests,
  Cargo locks and existing flake locks remain byte-identical.

Initial `first.log` retains a driver failure after five unit passes: the script
looked for `xtask` rather than the built `shelllist-xtask` executable. No strict
policy result is claimed for that attempt. Versioned v2 corrected only the
executable path; the pending/running v1 driver was not edited. Clean committed
replay is recorded separately in `clean.log` and `clean-invariants.json`.

Review disposition: this JSON/documentation-only change uses the checker's
existing exact per-lock mechanism; no checker, analyzer rule, threshold or runtime
code was changed. No Rust/QML Lens extraction is claimed for this policy-only edit.
This does not integrate the outstanding migration families or approve combined
Qt/native/package/performance gates, deployment or rollout.
