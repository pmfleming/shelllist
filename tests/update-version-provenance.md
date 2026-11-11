# Update version provenance — 2026-11-11

The reported T3 `0.1.8 → 0.1.8` comparison was correct for the vendor profile.
It did not reveal the generation's separately installed `0.0.33` package, which
the login launcher had selected. The change preserves the correct comparison
while exposing generation versions, current configuration locks, queue timing
and existing approval blockers.

## Coverage

- The real Qt Updates suite exercises a current vendor T3 profile with an older
  system fallback, a fixed source revision, Nixpkgs refreshed at candidate build,
  an invalid baseline and a queue that no longer matches the configuration.
  Native keyboard navigation leaves facts passive and sends no mutation or
  additional read; malformed refreshes retain the accepted snapshot, and an older
  backend clears optional evidence to unknown. The Applications catalog journey
  also checks simultaneous active/system versions and late-response ownership.
- Update worker status tests read private lock and queue fixtures with a disabled
  subprocess PATH. They distinguish automatic, manual and explicit revision
  policies; omit local/follows pins; preserve unknowns; report queue restarts and
  unreadable metadata without fetching or claiming deployment.
- Public record bounds and session projection tests reject malformed policy,
  dates and oversized records; retain the exact vendor comparison alongside the
  generation version; and preserve unavailable inventory separately.
- Existing generated protocol checks still cover production reply fixtures and
  invalid request/payload mutations; this optional overview extension does not
  change the transport API version or executable application contracts.

## Limits

Executed with the cached Nix development environment:

- Real Qt Updates suite: **49 passed**, zero failures or skips. Existing
  teardown-incubation informational messages remain.
- Native session overview: **6 passed**. Public status DTOs: **7 passed**.
  Worker status suite: **8 passed**, one existing opt-in resource audit ignored.
- Clippy for the three affected Rust libraries with `-D warnings`: passed.
- Focused strict QML lint, generated protocol checks and both Git whitespace
  checks: passed. Panel UI review: zero numeric override/new-wrapper prompts.

No real login, full NixOS rebuild, cross-user storage repair, or exhaustive
rendered/accessibility review is claimed by these tests.

This is a source change requiring coordinated Shelllist/update-daemon deployment.
No system rebuild, approval update, package installation or upstream fetch is
performed by the new read path. It does not repair the delayed updater's policy
of restarting quarantine on configuration revision changes.

The screenshot also shows an independent history/storage permission error. The
installed worker reports `I/O error (open): permission denied` when reading the
public Turso store. The pinned engine opens its `-tshm` coordination file for
writable shared-reader registration even on a read-only database; that file is
root-owned 0644. The existing same-process storage test covers `-shm`, not this
cross-user `-tshm` boundary. This change does not weaken file permissions, fall
back to potentially stale JSON, or claim that storage issue is fixed. The new
lock/baseline observations are independent of that database.

Revision dates describe source commits, not pin creation or installation dates.
Configured inputs are not proof of deployed inputs or latest upstream revisions.
Per-package Nix overrides and startup executable selection are not inferred.

Follow-up: the separate system read service is now implemented and qualified in
[update-daemon's observation-reader evidence](../../update-daemon/tests/observation-reader.md).
It covers the cross-UID Turso boundary without granting users write access; the
coordinated deployment is still pending.
