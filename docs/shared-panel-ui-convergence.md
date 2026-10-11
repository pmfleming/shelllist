# Shared panel UI convergence

Implementation scope: approved revised-plan **U1, U2, U3, U5, U6, U7 and U8**.
**U4 is excluded:** Display Back remains in the inspector with its existing
command, routing and guards. This record supersedes conflicting presentation
recommendations in the earlier phase record; historical HTML reviews are unchanged.

## Implemented families

| Item | Implementation | Engineering evidence |
| --- | --- | --- |
| U1 | `FieldRow` owns the label column, editor host, spacing and separator. `FormField`, `SettingRow`, labeled sliders and toggles share it. Labels stay left and wrap; no stacked-label option or panel-local breakpoint. Wi-Fi, Bluetooth, Battery, Display reference, resource range and Todo consumers migrated. | Shared-family alignment at 340/520/760px; actual consumer captures; existing native editor/session suites. |
| U2 | `FocusRing` has transparent browse paint and an opaque marker. Editing adds only an editor-local background and lower line. Saved selection, on-state and pointer feedback remain separate. | Native browse/edit/save/discard tests; no enclosing edit border; marker and draft assertions. |
| U3 | `FeedbackSource` contributes text, summaries, tone and priority without layout space. `FeedbackSlot` selects fitting summaries at 13px in a fixed allocation. Provider panels use the list footer; standalone panels use the same `StatusPanel` through `PanelSurface`. Errors no longer insert growing field/recovery blocks. | Long raw diagnostics and overlong-summary fallback; stable field bounds during real Activity/Battery/Audio/Media/Notifications errors; visible critical countdown/AC escape; Audio/Media outcome and tone survive inspector collapse. |
| U5 | Resources retains five equal-row cards, full-card plots, time axis and one range field. All cards have two readings at one viewport-derived scale and two theme-derived series colours. Battery history now uses aligned charge/signed-power tracks with muted blue/sage/amber foregrounds and readable light variants; semantic warning colour is retained. | Native resource keyboard/pointer, availability, zero, gaps, totals and geometry tests; normal/minimum captures. |
| U6 | Weather keeps its 192px frame, 48px metric strip, artwork, city/condition, high/low and dividers. Temperature uses 64/56px when fitting, otherwise the former 56/48px roles. | Native fitting at 360/420/600px, unchanged metric-strip bounds and actual Qt captures. |
| U7 | Essential panel metadata uses the 12px role; bounded status uses 13px. Bluetooth, clipboard confirmation and Activity count copy handle singular/plural. Signal units and cached/live semantics are unchanged. | Count cases for 0/1/many; existing signal-update/draft tests; metadata/readability checks. |
| U8 | Family tests and actual consumer capture assertions supplement, rather than replace, interaction/safety suites. Current evidence and remaining gates are separate below. | No blanket hardware/accessibility/translation acceptance claim. |

### Resource semantics

The former power-card byte reading was `disk_space_total_bytes`, **identified app
data**, not power, energy or swap. `ApplicationDataDetails` now shows total,
persistent and temporary bytes on Application details. It is passive and makes
no history request. Stopped-app observations must match `historyTargetId`; another
application's cached history cannot supply its values.

Visible approximation signs are removed, **not estimation semantics**. Accessible
transfer and energy labels retain “Estimated”; confidence, observed coverage,
missing intervals, `<0.01 W`, and unavailable-versus-zero remain intact. No backend
measurement, aggregation or sampling behavior changes. See
[resource semantics](application-resources.md).

### Feedback and interaction boundaries

- Domain owners retain complete diagnostics, acknowledgement, pending state,
  validation, retries and safety guards. The shared footer retains full accessible
  text; concise summaries are not replacements for those authoritative values.
- Safety messages outrank ordinary feedback. Countdown summaries retain time and
  the AC/cancel escape. Required confirmations are unchanged.
- Explicit Help can disclose content; automatic status does not resize rows.
  Recovery commands retain their geometry and are disabled outside their existing
  availability conditions, rather than appearing and moving subsequent controls.
- Editable-only Tab traversal, native arrows, Enter/Tab save, Escape discard,
  Alt commands, local drafts and preview rollback remain governed by the
  [keyboard contract](chooser-keyboard-workflow.md).
- Chart axes may retain 11px annotations. Native menus, required-input dialogs,
  bar/toast density, artwork, calendars and monitor maps keep their domain roles.
  These are not exceptions for ordinary setting-row composition.

## Twelve-panel consumer inventory

| Panel | Shared route / specific migration |
| --- | --- |
| Applications | Provider footer; inline range/settings; passive app data; two-reading Resources; fixed window/action feedback. |
| Wi-Fi | Provider footer; segmented rows use `FormField`; validation and advanced errors contribute without moving editors. |
| Bluetooth | Provider footer; inline Device list/Login state; full switches; stable adapter/name recovery; readable signal metadata. |
| Clipboard | Provider footer; native document/lease editor retained; failed-draft recovery does not insert an expanding error card. |
| Displays | Provider footer; inline reference setting; focus/policy feedback; stable command allocation. Back is not relocated. |
| Battery | Shared standalone footer; inline power/device/history/profile fields; warnings/countdowns; full-size threshold switches. |
| Activity | Shared standalone footer; inline Todo field; readable metadata and count copy; calendar semantics retained. |
| Time & Weather | Provider footer; original hero composition with fitted temperature enlargement; readable metadata. |
| Notifications | Provider footer; app/DND/timeline feedback and stable recovery; native grouped-history and deletion ownership retained. |
| Audio | One list-owned error outcome, including collapsed inspector; existing volume commands and mute control retained. |
| Media | Same list-owned error behavior; shared pin/mode controls; artwork and transport semantics retained. |
| Tray | Shared list/footer and metadata foundations; no invented setting or Back control; native-menu ownership unchanged. |

## Validation and limits

Local evidence lives in ignored `target/shared-ui-convergence/`. Captures are
**actual Qt renders of synthetic snapshots with recording transports**, not live
hardware screenshots or pixel goldens. Counts include Qt lifecycle hooks.

| Check | Result / evidence |
| --- | --- |
| Strict QML lint | Pass — `lint.log` |
| Full working-tree Qt suite | 345 passed, 0 failed, 1 existing renderer skip — `qml.log` |
| JavaScript | 17 suites passed, including 150 seed/mode contrast combinations — `javascript.log`, `run-javascript.sh` |
| TypeScript generation/type checking | Pass — `typescript.log` |
| Native offscreen runtime smoke | Pass — `smoke.log` |
| Registered panel captures | 28 passes, 110 images, both themes and normal/minimum sizes — `captures.log`, `captures/` |
| Fractional offscreen captures | 28 passes, 110 images at 1.25× — `fractional.log`, `fractional/` |
| Form captures | 4 passes, 10 images — `forms.log`, `forms/` |
| Display captures | 4 passes, 42 images — `displays.log`, `displays/` |

The full suite retains an existing software-renderer artwork-mask skip. Its log
also contains the existing teardown-incubation warning, Time/Weather fixture
undefined-to-bool warnings, and expected negative-path diagnostics; passing is
not a claim of a warning-free host. No tests were excluded or newly skipped.

**Not verified by this work:** hardware IME, a human screen-reader walkthrough,
real Bluetooth/Wi-Fi/power mutations, actual native tray menus, compositor masks,
physical display recovery, exhaustive translated catalogues, or a full sibling-aware
Nix/package build. Source-tree import checking is not package-build acceptance.
These gates remain open; synthetic captures and native key tests do not close them.

The new native family test caught a real constrained-editor-host alignment issue;
the shared host now fixes that boundary for switches as well as expanding editors.
Resource font sizing is computed once per grid, avoiding fractional cell-rounding
differences. Capture transitions wait for restored-width layout polish before
comparing geometry; model navigation tests wait for published result counts.

## Work preservation

The incoming source archive, hashes, index, HEAD, working patch and staged patch
are under `baseline/`. During implementation, the incoming staged patch, including
**76 documentation deletions**, and unrelated work were preserved. The subsequent
explicit request to commit everything authorizes the final commit to include all
pending repository changes, including those deletions and overlapping Resources,
notification, Bluetooth and choice-session work. Ignored local evidence is excluded.

Current contract/test documentation no longer links to the incoming retired review
files. Their historical counts are retained as history, not current acceptance.
`preservation.json` records pre-commit changed-file hashes, unchanged Back-command
verification and staged-patch preservation during implementation. The standalone
HTML plans in the parent Projects directory are untouched.
