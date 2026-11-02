# Stage 2: serialized Rust workspace owner

The bar daemon owns session-scoped allocation, reservations, placement, close
observations, cleanup and per-monitor presentation. All effects persist admission
before dispatch; unknown outcomes are looked up, never replayed. A restarted
owner fences old placement leases. Journal failures stop new effects.

Validation on 2026-11-02:

- `cargo test --locked --lib`: 301 passed, 6 existing opt-in tests ignored.
- `cargo clippy --locked --lib --tests -- -D warnings`: passed.
- Eight workspace tests cover concurrent allocation, duplicate/reused keys,
  restart fencing, corrupt/unwritable persistence, stale contexts, lost close
  replies, late arrivals, user adoption and fallback readback.
- The private installed-compositor integration passed with `move_local`, including
  guarded normal close, foreign-monitor refusal and preserving background focus.
  See `temporary-workspaces-spike.md` for the private compositor environment.

No desktop deployment is claimed. App launch integration and QML remain later
stages. Native dialogs and monitor hotplug need final qualification.
