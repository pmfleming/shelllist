# Notifications implementation checkpoints

Implementation of the five recommendations in `notifications-panel-review-and-plan.md`.
Unrelated worktree changes are excluded from these commits. No service reload or deployment.

## 1 — unified notification list

- Replaced Active/History and app-group results with one keyed list of individual live/history records and a single-message inspector.
- Legacy group/history entry points remain compatible. Selection is identity-owned, not a two-way index/key feedback loop; live/history transitions retain the same identity.
- Removed the eager expanded-group repeater. The formerly timing-out live-update/reply-focus test now completes, including its 205-record burst.
- Validation: notification Qt suite **9 passes**, registry suite **3 passes**, presentation JS checks pass. These use the recording transport and Qt 6.11.2 offscreen, not live notifications.
