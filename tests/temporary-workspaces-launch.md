# Stage 3: application routing and launch journal

The Rust app daemon captures monitor/workspace context at admission, resolves
saved/new/current routing, reserves through bar-daemon and submits only a new
window whose process ownership matches the launch. Ordinary desktop actions keep
their category routing. Launch-only shortcuts cannot save the new-workspace flag.

The private session journal stores caller/request identity, admission, destination,
pre-launch window/process baseline and checked launch receipts. Restart maps
unfinished work to `unknown`; lookup is read-only and cannot replay launch effects.
Recovery releases reservations through the serialized bar owner. The v2 settings
file imports v1 without overwriting it; category null and omitted category differ.

Validation on 2026-11-02:

- App library: 57 passed, 3 existing opt-in tests ignored.
- App Clippy, all targets with warnings denied: passed.
- Bar workspace regression suite: 8 passed after allowing background launches
  to retain their captured origin while requiring active context for manual `+`.
- Added migration, independent updates, null/omitted category, routing precedence,
  durable admission, caller isolation, changed request rejection, corrupt session
  and failed-persistence fencing tests.

Process termination and complete frontend/daemon integration remain stage 6
qualification gates. This evidence does not claim deployment.
