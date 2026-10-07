# Compact value rows — option C

Implemented the owner's selection of **C as the default**, rather than the
original A recommendation in [the visual exploration](../proposals/compact-text-fields.html).
The [keyboard contract](../chooser-keyboard-workflow.md) remains authoritative.

## Delivered

- Shared `FormField` now composes an inline purpose icon/name, native editor and
  optional commands over a passive separator. No filled resting box, external
  heading, routine footer or reserved empty support row. Long translated names
  wrap; the wrapper is not a focus target or transaction owner.
- Shared `FieldFrame`, `TextField`, `TextEditor` and `DropDownList` use the
  low-chrome treatment. Browse/edit feedback stays on the editable portion.
  Normal content height is 52 logical pixels, values 16px, editor padding 12px,
  command circles 32px. Search keeps its existing separate capsule presentation.
- A shared passive `FieldStateBadge` distinguishes read-only (lock) from
  unavailable (blocked). Values retain full contrast. Empty read-only inputs
  show a dash rather than a plausible example value; native accessibility also
  reports “Not set.” Locks never act as unlock buttons.
- Routine guidance is an explicit Help disclosure. Editable fields use scoped
  Alt+H; read-only Help/Copy commands are named entries in the existing Alt+J
  menu, not unreachable commands scoped to skipped fields. Errors, recovery
  messages and pending status remain visible. External domain Help can suppress
  a duplicate embedded command while retaining the full accessible guidance.
- Multiline editors start at one line, grow with content to 112px, then scroll.
  Explicitly sized document editors retain their allocation. DNS remains one
  native list editor; Enter/Tab saves and Shift+Enter inserts a newline.
- IP/DNS fields use concise inline names and semantic icons. Address and prefix
  remain separate fields, side-by-side where they fit and stacked at narrower
  widths. Read-only address/gateway/DNS Copy uses `WifiController.copyText` and
  the existing daemon publisher/acknowledgement/transport guards. No clipboard
  backend was introduced in the shared UI layer.
- Existing FormField consumers inherit the default; Wi-Fi credentials,
  Bluetooth names/radio/audio, display settings, application category, reply,
  todo and notification-duration fields have explicit semantic identities.
  Full names remain in accessibility. The development gallery uses the new
  family too.

## Preserved boundaries

No per-keystroke setting writes, normalization, cross-field paste splitting or
new traversal model. Native cursor/selection/IME, source bindings, local drafts,
raw-buffer IP validation, whole-group readiness, daemon acknowledgement and
retry/failure ownership remain intact. Clipboard's explicit `editingAllowed`
gate can still acquire a lease before its native editor becomes writable; this
is not interchangeable with a permanent read-only value. Secrets do not gain
automatic copy actions or presentation-memory storage.

## Verification

- Full Qt suite with packaged Roboto Flex, Material Symbols Rounded and
  JetBrains Mono fonts: **419 passed, 0 failed, 1 skipped**. The skip is the
  existing MediaChip rounded-artwork pixel test requiring an RHI renderer.
- `tst_compact_fields.qml`: actual keyboard/pointer delivery, inline geometry,
  passive labels/locks, explicit Help during browsing and editing, read-only
  commands through Alt+J, editable-only traversal, save/discard, error/name
  growth, bounded multiline resize, and light/dark value/badge contrast.
- `tst_ip_fields.qml`: real network panel at 720px and 360px, automatic-value
  locks, collapsed guidance, prefix space, single-line/expanded DNS and guarded
  clipboard publication without network mutation. Existing raw-buffer rejection
  and draft/acknowledgement tests still pass.
- `tst_material_feedback.qml` checks painted text/error/focus contrast over the
  actual parent surface rather than assuming an opaque input fill. Existing
  field, application-settings and Clipboard lease/recovery suites pass.
- Final `tests/run-qmllint.sh` passes for the full production/gallery/test tree;
  an earlier warning in concurrent content-state work was resolved independently.
  `git diff --check` also passes.
- Native software-rendered captures were inspected at wide/narrow widths with
  the packaged fonts (not CSS mockups). Temporary capture hooks were removed
  from the tests after inspection.

Live compositor, physical IME and screen-reader acceptance remain separate from
these offscreen checks. This is a shared visual/composition change, not a claim
of new backend capabilities or full accessibility acceptance.
