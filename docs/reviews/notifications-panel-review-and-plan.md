# Notifications panel: review and improvement plan

**Status:** review/proposal only; no implementation changes.
**Reviewed:** 2026-10-04, Shelllist `4725ac9`, bar-daemon `e4b4032`.

## Recommendation

Replace the Active/History split with **one searchable notification list**. Select individual notifications, not app buckets. Put a **settings gear inside search**, using the shared trailing-action slot, and remove the standalone DND button/duration accessory. Keep DND as an acknowledged setting on the settings page.

Most importantly, separate **popup visibility** from **notification lifetime**. A popup disappearing should not, by default, make a retained notification unactionable. Closed historical notifications must nevertheless remain closed: do not attempt to revive their old D-Bus actions.

Keep the shared chooser keyboard contract. Improve notification selection, command discoverability and data updates rather than introducing a notification-specific navigation system.

## Findings

### 1. “Active” is a short-lived protocol state, not a useful default view — high priority

- `bar-daemon/src/activity/notifications/model.rs:96–102`: a normal notification with server-default expiration gets **5,000 ms**. Critical/default and explicit zero-timeout notifications are exceptions.
- `engine.rs:476–504`: expiration removes the notification from the active map and emits `NotificationClosed(EXPIRED)`.
- `shelllist/activity/NotificationController.qml:13–22`: the panel defaults to Active and displays only that map. Bar entry points also request Active.
- `NotificationHistoryRow.qml:20–24, 112–113, 182–186`: actions/default activation/reply availability depend on being active. History is largely a read-only archive by the time the panel opens.

**Conclusion:** the rarity of Active is explained by the lifecycle. Simply defaulting to History would improve visibility but would not restore app actions.

### 2. Some valid app actions are misclassified as inline replies — high priority

`qml/Shelllist/Ui/NotificationPresentation.js:7–8` treats any action key containing `reply` as an inline-reply action. `standardActions()` then removes it from the app-action buttons. The UI sends `notifications.reply`/`NotificationReplied` instead of invoking that app action.

A direct helper probe with `mail-reply-sender` produces an empty standard-action list and classifies it as inline reply. This is a concrete bug, not just a discoverability problem. SwayNC distinguishes the specific `inline-reply` key from ordinary actions, including ordinary reply actions.

The daemon's `engine.rs:408–416` also accepts replies based only on nonempty text and active ID; it does not check inline-reply support. Fix both ends, retaining request validation and acknowledgement behavior.

### 3. The keyboard model selects groups, but commands operate on messages — high priority

- `NotificationController.qml:69–73`: Enter only opens/focuses the selected app group's details.
- `NotificationHistoryGroup.qml` creates all messages in the group using a `Repeater` inside a scrolling details page.
- Quick actions are opacity-hidden until hover/reply/focus. They have no explicit access keys.
- Shared `DetailsNavigation.qml` deliberately excludes action buttons from field Tab order. It exposes unassigned commands through **Alt+J**, but a group can produce many indistinguishable “Dismiss”, “Reply” and “Snooze” entries.

Actions are **not universally unwired**: pointer activation exists, and the Alt+J menu-opening test passes. The problem is the combination of short lifetime, group-level selection and poorly exposed per-message commands. The current tests do not prove a full selected-message → daemon → application action flow.

### 4. Repeated rendering has plausible data/layout causes, not a proven whole-model reset

The current path is approximately:

```
bar stream / panel snapshot / panel stream
  → shared notification state assignments
  → derived group arrays → serialized group payloads → row updates
  → 120 ms history debounce → history merge → another derived-model update
```

Evidence:

- `bar/BarController.qml:213–217` and `activity/NotificationBackend.qml` both feed the shared state when the notification panel is active. Activity has another forwarding path. Shared daemon transport does not by itself deduplicate these store assignments.
- `NotificationState.qml:160–169` schedules history work for both summary and active changes; it does not gate this on a new history revision. `applyHistory()` assigns a newly merged array even for unchanged records.
- `NotificationController.qml:109–122,164` rebuilds serialized group payloads when the derived groups change. A record update can reserialize a whole app group.
- `NotificationHistoryGroup.qml` animates implicit height, eagerly instantiates expanded records, and uses different keys for active records and history wrappers.
- `engine.rs:374–389,476–504`: group clear and expiry batches publish intermediate states through each `close_locked()` call. `StateStore` suppresses equal values, but intermediate states genuinely differ.

**Important counter-evidence:** `SerializedListModel.qml` already overrides generic reset/chunk behavior and performs keyed reconciliation. Do not replace it or claim that every notification update clears the list. Profile model changes, delegate lifetime and layout separately.

The existing live-update/reply-focus Qt test timed out in this review (see validation). This makes rendering stability a release blocker, but does not identify the exact cause of the visible redraw.

### 5. The settings affordance does not match other chooser panels

`NotificationContent.qml:19–21` uses the shared power slot for DND and adds a duration accessory. There is no notification settings search action.

Use the precise Bluetooth precedent in `bluetooth/BluetoothDeviceListPane.qml:22–35`: `searchActionIcon`, accessible description and `onSearchActionRequested`. Wi-Fi uses the same shared trailing-action mechanism for QR scanning; it is an example of the mechanism, not currently a notification-like settings page.

### 6. Historical identity is unsafe for action eligibility

`NotificationState.isActive(id)` compares only the numeric D-Bus ID; drafts and pending reply state are also ID-keyed. The daemon seeds its next ID from restored active records, so IDs from closed historical records can be reused after restart. An old row can consequently appear actionable against an unrelated current notification.

`recentRecords()` already recognizes the identity issue and deduplicates using ID plus creation time, but row eligibility/drafts do not. A unified model needs one stable record identity across live state, persistence, replies and selection; numeric D-Bus ID alone is insufficient.

### 7. Action invocation and application focus are separate concerns

`NotificationBackend.invoke()` always supplies a null activation token. The daemon can emit `ActivationToken` before `ActionInvoked`, but has no token to forward here. This may explain an application not coming forward on Wayland even when it received an action; it does not explain actions being absent.

Test both signal delivery and compositor activation. Do not claim either from a successful JSON response alone.

## GitHub references: keyboard-oriented notification UX

These are keyboard-first tools or applications with substantial keyboard notification support—not all are terminal UIs. Sources below were read from GitHub; observations are source/documentation-based, not hands-on usability trials.

| Project and source | Observed pattern | Apply to Shelllist |
| --- | --- | --- |
| [SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter), [shortcuts](https://github.com/ErikReider/SwayNotificationCenter/blob/main/README.md#control-center-shortcuts), [lifecycle](https://github.com/ErikReider/SwayNotificationCenter/blob/main/src/notiDaemon/notiDaemon.vala) | Up/Down select notifications; Return invokes the default action; alternatives have explicit keys. Expiry hides non-transient floating notifications without closing their retained center entries. | Closest functional reference: select messages and separate toast visibility from actionable center lifetime. Do **not** copy Return-to-dismiss when no default action or its plain-letter shortcuts. |
| [Dunst](https://github.com/dunst-project/dunst), [dunstctl](https://github.com/dunst-project/dunst/blob/master/docs/dunstctl.pod), [history/actions](https://github.com/dunst-project/dunst/blob/master/docs/dunst.5.pod) | Keyboard-bindable default action, action menu, close and history recall. Documentation explicitly says actions are invalidated after closing, even when history is redisplayed. | Offer a clear primary action and a discoverable alternative-action menu. Never imply that archived action labels are still callable. |
| [mako](https://github.com/emersion/mako), [makoctl](https://github.com/emersion/mako/blob/master/doc/makoctl.1.scd), [configuration](https://github.com/emersion/mako/blob/master/doc/mako.5.scd) | Invoke/dismiss by notification ID; `menu -n ID` sends that notification's actions to a keyboard picker. Separate history/restore commands; documented activation-token integration. | Commands must have an explicit notification target. Keep app action selection, dismissal and history management distinct. |
| [Rofi](https://github.com/davatorium/rofi), [dmenu interface](https://github.com/davatorium/rofi/blob/next/doc/rofi-dmenu.5.markdown) | Searchable selection, explicit accept/cancel results, programmable actions; synchronous input mode is available alongside asynchronous population. Not itself a notification server. | Reuse the search → selected result → explicit action pattern. Never execute on highlight. Publish coherent updates rather than flashing intermediate lists; do not block on all history. |
| [VS Code](https://github.com/microsoft/vscode), [notification commands](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/notifications/notificationsCommands.ts), [actions](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/notifications/notificationsActions.ts) | Explicit focus context for notification commands, separate expand/collapse/clear operations, command-palette entries, configuration and copy-message actions. Opening the center hides toasts. | Stable selected-message context, commands discoverable without hover, copy text even when no app action exists, no duplicate toast/center presentation. Keep Shelllist's own key bindings. |
| [nvim-notify](https://github.com/rcarriga/nvim-notify), [history](https://github.com/rcarriga/nvim-notify/blob/master/README.md#viewing-history) | Notifications remain available in `:Notifications` and a searchable Telescope history after popups disappear. | Make retained/searchable content the primary panel experience, not a view that becomes empty after a few seconds. |
| [noice.nvim](https://github.com/folke/noice.nvim), [README](https://github.com/folke/noice.nvim/blob/main/README.md) | Consistent message history, keyboard pickers, last-message and dismiss-visible commands; configurable routing and replacement of updates. | Separate transient presentation from retained records, replace updates in place and keep the current interaction stable. |

### Best-practice synthesis

1. Notifications are individually selectable; actions have an unambiguous selected-message context.
2. Popup timeout, notification closure and history deletion are different operations.
3. Common commands are explicit; arbitrary app actions belong in a keyboard menu.
4. History remains searchable after a popup disappears, without pretending closed app actions still work.
5. Updates should preserve selection, scroll, message identity and any reply draft.
6. Borrow principles, not conflicting keymaps. `docs/chooser-keyboard-workflow.md` remains normative.

Protocol constraints: the [Freedesktop specification](https://specifications.freedesktop.org/notification-spec/latest-single/) defines default/zero/positive expiration, `resident`, `transient`, actions and persistence. Advertising persistence is more than saving an unactionable SQLite log. SwayNC's behavior is a useful product precedent, not a reason to silently ignore explicit client timeouts.

## Proposed panel

```
[ Search notifications…                         ⚙ ]

App · time     Notification summary                >
App · time     Another notification                >
App · time     Older notification                  >

Details: selected message OR Notification settings
```

- One newest-first list, with app identity, summary, time and a short preview. No Active tab, no DND power button, no duration chip. No decorative “active” dot is necessary; retain capability state internally.
- Initial implementation: **one selectable row per notification**, virtualized through the shared result list. App grouping can be a later visual/filter feature, not another navigation layer or an eager stack of cards.
- Details show one message, its full body and explicit commands. Remove the nested message-list-in-details pattern.
- Preserve valid live records and loaded history without duplication. Show loading only before first data; refresh in place thereafter. Distinguish empty, filtered-empty, unavailable-backend and failed-load states.
- Search initially covers loaded records and says so. Full-history search is a separate daemon query/index task; do not suggest that the first 50 records are the entire archive.
- “Dismiss” closes a live notification. “Delete from history” deletes retained data and requires a separate API. “Dismiss all” must never be labelled “Clear history”. Move bulk commands to an explicitly labelled menu rather than the present unscoped trash icon.
- Closed records still support reading and copying. A validated desktop-entry-based “Open app” may be offered separately, but is not equivalent to invoking the original notification action. Never execute arbitrary text from notification content.

### Search settings

Use `ChooserListPane.searchActionIcon` with the Bluetooth gear and `powerVisible: false`. Pointer activation and the existing **Alt+Enter** search action open Notification settings, even with zero records or no selected result.

Settings initially contain only supported behavior:

- Do Not Disturb switch.
- Duration choice: 30 minutes, 1 hour, until turned off; show the acknowledged deadline when enabled.
- A concise explanation that DND suppresses popups, not retained center entries.

Opening settings, browsing a duration or closing the page must not enable DND. Duration changes use shared deferred editing; DND remains daemon-acknowledged. Backend failure retains the previous acknowledged state and offers retry. No new per-app settings should be mocked without daemon support.

Use an independent settings context/memory key and restore the previous result/search position on return, following Bluetooth/Displays. A noninteractive DND status indicator is acceptable; the standalone DND **button** is removed.

### Keyboard behavior

| Context/key | Proposed behavior |
| --- | --- |
| Search/arrows, results Up/Down, printable text | Existing shared chooser behavior. Results select individual notifications. |
| Results Right / Left | Expand/collapse the selected message without moving focus. |
| Results Enter | Invoke the live default action, if one exists; otherwise open details, without dismissing. |
| Alt+J | Named commands/app actions for the selected notification only; available from result context too, without opening an unrelated group. |
| Alt+O / Alt+D / Alt+Z | Open/default action, dismiss, snooze respectively, only when supported. |
| Alt+R | Reply/Send using one active command registration; never duplicate access-key registrations for Reply and Send. |
| Tab / Shift+Tab | Shared region navigation, then editable fields only. Action buttons are not field stops. |
| Reply Enter / Escape / Tab | Save draft / discard field edit / save and traverse, following the contract. Sending is an explicit command, not an accidental field-save side effect. |
| Escape | Dismiss menu/editor first, then settings/details, then panel. |
| F5 | One coalesced refresh, preserving visible records and interaction state. |

Selected-message commands must be available without pointer hover and must obey shared popup/modality guards. J/M/S remain reserved. Hold-Alt hints and command-menu labels provide discovery; do not add a panel-local shortcut overlay. If list-context commands need shared chooser support, implement and test that extension centrally rather than bypassing navigation.

## Implementation plan

### Phase 0 — establish reproductions and contracts

1. Triage the live-update/focus test timeout before changing behavior. Add counters for store applications, revisions, history requests, model changes, delegate creation/destruction and layout passes.
2. Capture cold open, warm reopen, one arrival, replacement, expiry, burst and history page append. Compare animations enabled/disabled; identify whether the observed redraw is model churn, geometry change or both.
3. Use an isolated D-Bus test session with a notification client that records signals: default + two app actions, ordinary `reply`, `mail-reply-sender`, true `inline-reply`, resident, transient, timeout -1/0/positive, snooze and DND cases.
4. Establish structured identity/lifecycle/capability fields and the policy below before touching rendering. Do not run synthetic clear/dismiss operations against the user's live notification history.

**Exit:** repeatable evidence for current failures; agreed UI and lifecycle behavior; no claim that passing helper tests validates application actions.

### Phase 1 — daemon lifecycle, identity and action correctness

Files: `bar-daemon/src/activity/notifications/{model,engine,persistence,server}.rs`, `src/api/notifications.rs`, protocol definitions/generated consumers as needed.

- Introduce separate toast visibility/deadline and protocol-live state. For non-transient notifications using server-default expiry, prefer retained actionable center entries after the popup hides. Explicit positive client expiry still closes the notification; zero must not cause automatic protocol closure. Preserve critical urgency policy and transient non-persistence.
- Respect `CloseNotification`, user dismissal, resident-after-action behavior, snooze and action-key validation. DND must not consume the user's opportunity to act by aging out ordinary default notifications unseen.
- Never resurrect already closed actions. Restored historical records after daemon restart must not automatically be declared callable merely because payloads survived; define session validity and client reconnection/replacement behavior explicitly.
- Give records a stable identity present in both live and history data. Use it for UI selection/drafts and revalidate the current live ID/action at invocation. Prevent ID reuse from targeting an old record's command at a new notification.
- Recognize the exact supported inline-reply extension; preserve ordinary reply actions. Validate inline-reply capability in the daemon. Keep pending/error/retry state and acknowledge requests accurately; an emitted signal is not proof the app completed the action.
- Publish one coherent final update per logical mutation/batch; keep required per-notification D-Bus close signals. Preserve serialization, persistence reservation/backpressure and error handling.
- Introduce bounded retention/overflow semantics for longer-lived center entries. Do not silently retain actions forever, silently evict them, or relax existing safety limits.

**Exit:** Rust/protocol tests cover popup-hidden-but-actionable defaults, true closure, transient handling, restart identity, inline reply classification and signal order. Update capabilities to match what is actually supported.

### Phase 2 — one state owner and stable incremental presentation

Files: `NotificationState.qml`, `NotificationBackend.qml`, `NotificationController.qml`, `NotificationPresentation.js`, `bar/BarController.qml`, `shell/SurfaceRegistry.qml`.

- Route shared notification updates through one canonical store application path. Keep shared daemon transport and bar/toast access; remove redundant store writers or reject equal/older revisions consistently.
- Merge live records/history into a normalized keyed model. Keep identity stable when a live record receives its history ID or becomes closed. Scope revision comparisons to daemon session/generation so restart does not make all new updates look stale.
- Refresh history only for relevant changed revisions, opening an uninitialized view, F5 or gap recovery. Coalesce simultaneous requests, ignore stale responses and avoid no-op array replacement.
- Reconcile rows incrementally; retain the existing serialized model's no-reset protection unless measurements justify a replacement. Stop serializing every message in an app group just to update its list summary.
- Preserve selected key, viewport anchor, reply draft/caret and open/collapsed mode. When the selected item is removed, select a predictable neighbour without invoking anything. Avoid bulk height animation during data reconciliation.
- Keep paging explicit/bounded. Current paging is triggered by proximity to the end of the **app-group list**, which can stay short even while history grows; use notification-row pagination and test large single-app histories.

**Exit:** equivalent snapshots cause no model writes; a logical change produces one coherent visible update. Surviving rows/editors are not destroyed. Paging/bursts do not jump focus or repeatedly animate the list.

### Phase 3 — simplify the panel and make commands usable

Files: `NotificationContent.qml`, `NotificationController.qml`, existing history row/group components, new focused settings/detail components where useful; shared chooser command plumbing only if required.

- Remove Active/History controls and DND power/duration UI; install the search gear/settings page.
- Replace app-group results with notification results and a single-message detail view. Remove obsolete nested-stack/selection code rather than leaving two competing models.
- Expose selected-message default/alternative actions, dismiss, snooze, inline reply and copy. Show meaningful unavailability/errors instead of dead clickable affordances. Preserve arbitrary app action labels and keys.
- Make common commands visible for keyboard selection, not just hover. Scope Alt+J to one record. Prevent repeat dispatch while requests are pending where appropriate.
- Update bar, agenda and toast entry points so legacy `active`/`history` requests map to the unified list, and group requests reveal a sensible message. Preserve return-to-agenda behavior and shared reply drafts.
- Keep archive deletion out of scope unless implemented end-to-end. No button promising history deletion should call `notifications.clear`, which only dismisses live records.

**Exit:** a keyboard-only user can open settings with no records, find a message, invoke every supported action and return to the previous context. Existing chooser contracts and other panels remain intact.

### Phase 4 — end-to-end acceptance and documentation

- Actual Qt key/pointer tests: search gear, empty settings, result movement, default action, arbitrary actions via Alt+J, normal versus inline reply, send failure/retry, DND acknowledgement, layered Escape, modal suppression and access-key uniqueness.
- State/render tests: cold/warm open, equal snapshots, out-of-order replies, restart, live→history identity, reused numeric ID, replacement, paging, a 205+ notification burst and a large single-app history. Assert delegate/editor survival, viewport anchor and bounded refresh count.
- Isolated D-Bus integration: confirm the application receives the correct `ActionInvoked` key / inline-reply signal exactly once and the correct close reason; closed records must never emit actions.
- Real compositor acceptance: obtain/forward a valid activation token when available; verify the target app comes forward. Test failure/no-token behavior without conflating focus denial with action delivery.
- Render short/narrow and large panels, light/dark, long bodies/action labels, unavailable daemon and SwayNC fallback. No full-list flash, duplicate live/history rows, eager giant details stack or hover-only essential command.
- Run Rust tests, notification and shared chooser Qt suites, presentation checks and lint. Update `docs/activity.md`, the keyboard contract where primary-action behavior changed, and manual acceptance notes. No deployment/service restart is part of this proposal.

## Validation performed during this review

- Passed: `tests/check-notification-presentation.js` (existing adversarial identity checks).
- Passed: Qt 6.11.2 offscreen `tst_notification_actions.qml`: **4 passes including setup/cleanup**.
- Passed: isolated `Notifications::test_quickActionsUseCommandMenuNotFieldTraversal`: **3 passes including setup/cleanup**. This proves menu reachability, not dispatch to a real app.
- Direct JS probe confirmed that `mail-reply-sender` is incorrectly classified as inline reply.
- Incomplete: full `tst_notifications.qml` timed out after 60 seconds, following setup and two passing tests. Isolated `test_liveUpdateRetainsReplyDelegateAndFocus` also timed out after 20 seconds. No full-suite pass is claimed; investigate this before accepting the rendering changes.
- No Rust suite, live D-Bus action client, frame capture or compositor activation test was run. Redraw causes above are code-level hypotheses until instrumented.

Temporary research/test evidence: `/tmp/notification-panel-review/`. No services were restarted or notification data mutated. The pre-existing `shelllist/flake.nix` modification was left untouched.
