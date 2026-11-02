# Notification v2 paired cutover qualification

Implementation: Shelllist `29054ad`, bar-daemon `32b8558` / `5515768`.
Qualified 2026-11-02 with Qt 6.11.1 and Rust 1.95.0. Later completion commits
update documentation only.

- Full `tests/run-qml-tests.sh`: **714 passed, 0 failed, 1 existing skip**.
- Strict `tests/run-qmllint.sh`: passed.
- `cargo xtask contract bar --bin ../bar-daemon/target/debug/bar-daemon`: checked
  fixtures and frontend registry match the newly built producer.
- `cargo xtask build-inputs`: Rust 1.95.0, 12 locked roots and 49 shared
  dependencies aligned. The existing sibling-source build workflow is unchanged.
- Daemon full Rust suite: **342 passed, 0 failed, 8 existing ignored cases**.
  Release notification suite explicitly including the large window: **49 passed**.
  All-target check, strict Clippy and daemon build passed.

The Qt cutover regression starts with old cached/live notifications and a pending
deletion token. Disconnect clears catalog/timeline state, action ownership and
the token, while retaining unsent text under its full record identity. A late
response cannot restore the old page; confirming the old deletion dispatches
nothing. A new snapshot with revision zero and an empty history page is accepted,
and subsequent live delivery works. Other notification suites retain interaction,
settings, actions and bounded-cache coverage. No visual layout or key model was
changed, and no numeric visual overrides were added.

Implementation/tests added only Rust and QML. Existing development runners were
used; no new scripts, JavaScript modules or migration tools were introduced.
Tests use temporary stores and recording transports. This is source/build
qualification, not a live service deployment or compositor acceptance claim.
The default fresh `notifications-turso-v2.db` is created after the matched build
is deployed and the daemon restarts; explicit database overrides require a fresh
path. Old saved notification state is intentionally not imported. See the
[cutover contract](../contracts/notification-cache.md#daemon-restart-and-relational-storage-v2)
and [daemon evidence](../../bar-daemon/tests/notifications-v2-qualification.md).
