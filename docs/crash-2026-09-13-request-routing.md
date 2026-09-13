# 2026-09-13: request-routing crash and Rust bridge fix

## Evidence

Quickshell 0.3.0 / Qt 6.11.1 crashed at 15:25:35 CEST while opening Clipboard.
Quickshell restarted; the domain daemons remained running. The installed config
predated the battery-history styling change.

The core dump's recovered QV4 stack identified:

```
ClipboardController.applyHistory
ClipboardBackend.query
DaemonBackend.call
DaemonSessions.call
session.routes[id] = {...}
QV4::Object::insertMember -> SIGSEGV
```

A fake-client QML test reproduced SIGSEGV in the same Qt function in about 3ms,
with no clipboard contents, D-Bus service, compositor, or live UI. It requested
five pages per query, registered each next page during response delivery, and
churned query IDs on the same session. The tested baseline was Shelllist
`5d90c519d17aec6b6f467678a4b71179371e33b1`. This confirms the routing-table
trigger; it does not establish every detail of the underlying Qt defect.

## Change

- `DaemonSessions.qml` no longer keeps `routes` or `subscriptionOwners` tables.
- The Rust JSONL bridge accepts typed consumer/local-ID/kind/generation metadata
  and carries it with each request task and response.
- The Rust output actor owns live subscription addresses and supplies event
  routing, preserving response-before-event ordering.
- Detaching a view requests bridge-owned subscription release. Late subscribe
  replies still carry their route, allowing cancellation after view destruction.
- QML retains only live view handles and base-subscription visibility state;
  it drops retired-generation responses/events.
- Request admission is bounded before spawning Rust tasks, with separate control
  capacity. QML startup buffering is also bounded. No failed effects are replayed.
- Recovery fences late stdout; normal shutdown still drains accepted replies so
  backend pending flags settle.

## Regression coverage

`tests/qml/tst_daemon_sessions.qml` exercises 20,000 paginated responses and
reentrant next-page requests through the actual QML registry. It also asserts
that the old dictionaries do not exist. It passes on Qt 6.11.1 after the change.

`tests/check-daemon-boundary.js` covers kind-authoritative routing, pending
subscribe/reopen adoption, closed/destroyed views, late replies, generation
rejection, owner-scoped events, startup queue limits, and failed-generation
non-replay. The complete QML suite passed (194 tests at implementation time).

The framework's Rust tests cover response addressing, early subscription events,
consumer/generation isolation, ownership cleanup, failed cancellation, admission
limits, and 20,000-request churn. The real `clip-daemon client` integration test
checks 4,000 addressed replies through its stdin/stdout bridge and EOF drain,
using an unavailable test bus rather than the user's clipboard service. All five
daemon crates passed `cargo check --all-targets` against the updated bridge.

## Deployment

These source changes are not a live session deployment. Rebuild **both** the QML
config and all Rust daemon client binaries with the updated framework input;
app-daemon contains a vendored copy, updated alongside this change. Advance the
Nix input pins after committing the framework and daemon changes. Do not deploy
the QML change alone: old bridges ignore the route field and the frontend will
report that routed client binaries need rebuilding.

No automatic rollback to a JavaScript route dictionary is provided because that
would restore the reproduced crash path. Battery computation and clipboard
snapshot/cursor migration are separate follow-up work, not part of this fix.
