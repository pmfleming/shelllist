# Autostart validation — 2026-11-09

Scope: the [application autostart contract](../contracts/application-autostart.md),
implemented by Shelllist and the sibling `app-daemon` checkout.

- `tests/qml/tst_application_settings.qml`: 9 passes, zero failures. Native Qt
  input covers forward/reverse switch traversal without writes, Enter and pointer
  activation, pending guards, failure/retry, stale acknowledgements, observed
  values, unsupported backend values and independent category feedback.
- `tests/test-native-application.py`: private Qt → JSONL → daemon journey passes.
  Enables autostart, refreshes it, verifies the user desktop file and observes
  the saved state after daemon restart. The category/launch-failure/retry journey
  remains covered. Uses a private bus, isolated XDG paths and a stub launcher.
- `cargo test --all-targets` in `app-daemon`: 92 passes, zero failures, 10 existing
  opt-in/helper tests ignored. Autostart cases cover inherited-entry disabling,
  metadata preservation, minimal masks, idempotent enabling, fresh entries,
  invalid IDs, malformed files, managed symlinks and invalid service requests.
- Generated protocol bindings and reply fixtures come from the updated Rust
  producer; `node tests/check-generated-contracts.js` passes.
- Application action regressions: 26 Qt passes; application stream recovery:
  5 Qt passes, zero failures in either suite.
- `cargo clippy --all-targets -- -D warnings` passes in `app-daemon`.
- Strict QML lint passes. `tests/review-panel-ui.py --base HEAD` reports the
  shared `ToggleRow` composition addition and no numeric role overrides or new
  wrappers. Applications owns the new switch; shared UI owns its geometry.

This does not test a real logout/login or claim that every desktop processes XDG
autostart. The session retains execution and desktop-condition ownership.
Deploy the updated application daemon together with the frontend. Unrelated
concurrent workspace changes are outside this feature's scope.
