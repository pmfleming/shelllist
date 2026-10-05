# Form-field family implementation — 2026-10-05

Implemented after approval of the [illustrated proposal](../proposals/form-field-family.html).
Search remains distinct; no services or settings were deployed or changed.

## Commits

- `0be6b4f` — record approval of the proposal.
- `8922cae` — shared filled paint/tokens, passive `FormField`, native text/choice controls and bounded multiline editor.
- `da748ba` — names, credentials, pairing, replies, todo entry and Clipboard consumers.
- `5983016` — IP/prefix composition, multiline DNS, save-time validation and safe native paste boundaries.
- `922922e` — remaining choice compositions, numeric units, gallery and rendered regression coverage.

## Delivered

- 56px normal containers, 16px value text, 12px corners, opaque Surface Container Highest, 16px padding and an inset idle keyline. Native font metrics are retained.
- Explicit 48px compact support without shrinking type; current production consumers use normal fields. Old 34/38/40/42px form overrides were removed; button/slider/toggle dimensions are independent.
- Persistent 14px labels and a shared 12px supporting/error/status row, with required metadata and native accessible names. Existing contextual card/setting-row labels remain appropriate for their selectors.
- Prefix/suffix slots that never enter the value; Display Focus uses a `px` suffix and domain range. Password/trailing actions and choice-menu rows have 48px targets. Read-only text keeps normal contrast.
- The existing browse marker and edit edge remain immediate and affect only the editable area. Search explicitly bypasses form paint and retains its existing capsule, height, text size and query behavior.
- `TextEditor` retains native plain-text editing inside one focus scope and a bounded scrolling viewport. Selection, caret restoration and Clipboard lease/retry ownership remain intact. Enter/Tab saves; Shift+Enter adds a line.
- One native editor per IP address, a separate prefix field and one multiline DNS editor. Wide address/prefix groups reflow vertically before reducing useful address space. Required/manual and automatic/read-only states are explicit.
- IP validation retains Invalid / Intermediate / Acceptable states. Errors appear on explicit field save and update as the draft is corrected; Tab is not trapped. Existing group readiness blocks invalid backend requests.
- Native address/prefix buffers no longer truncate at 15/45/3 characters. Accepted-value limits live in validation. Buffer exhaustion itself is invalid, including an address followed by enough whitespace to hide a clipped suffix. DNS retains complete pasted lists and rejects over-limit values instead of saving a shortened list.
- CIDR, unsupported scoped IPv6 and malformed addresses stay visible with specific explanations. No automatic CIDR splitting, normalization, octet widgets, chips or new network capability was introduced.

Acknowledgement, capability guards, secrets, submit/send ownership, Display Preview/Keep/Revert and the pointer-only Power chart are unchanged. Field-local text never enters presentation memory.

## Validation actually run

- Strict `tests/run-qmllint.sh`: pass.
- Native Qt suite: **237 passes, 0 failures, 0 skips**.
- `check-ip-validation.js`: **55 checks**.
- Material palette validation: **150 seed/theme combinations**.
- Both native runtime smoke configurations: pass. The offscreen platform still reports its unsupported window-mask advisory.
- Rendered field checks cover seven seeds in both themes, rest/browse/edit/error fill contrast, the bottom indicator and the opaque browse marker. Text meets 4.5:1 and meaningful indicators meet 3:1 in those checked states.
- Actual Qt interactions cover native clipboard paste, full-buffer rejection, CIDR/zone retention, prefix bounds, intermediate input, error timing, Tab continuation, discard to a retained domain draft, multiline DNS, the real settings-page write guard, acknowledgement, native accessible labels, unit separation and scrolling.
- `tests/manual/tst_form_review.qml`: **4 passes**, eight real Qt captures, no backend mutations. Inspecting these catches presentation mistakes that parser/key tests cannot—for example, an unmapped error symbol was fixed and regression-tested before final captures.

Logs: `/tmp/form-final-checks.log`, `/tmp/form-captures.log`.

### Full sibling-aware gate: incomplete; untracked-file blocker resolved

The initial `tests/check-sibling-boundary.sh` attempt, using the framework development environment, was blocked by these untracked review documents:

- `docs/reviews/material-gap-review-2026-10-05.html`
- `docs/reviews/material-gap-review-2026-10-05.md`

Following the owner's follow-up, both reports were committed unchanged in `1e31be1`. No untracked files remain in `shelllist`, and the worktree preflight now succeeds. Two retries reached the Nix build matrix but exceeded the 240-second and 600-second command limits respectively; a full gate pass is still not claimed. Latest log: `/tmp/form-sibling-gate-tracked-reviews-final.log`. The earlier missing-Cargo environment issue was resolved by sourcing the framework's development environment.

Live compositor/scaling, hardware IME, primary-selection pointer paste and screen-reader acceptance remain outstanding. Offscreen checks do not certify these. Unrelated pre-existing worktree edits were preserved, including the Displays telemetry paragraph in the interaction contract.

## Real Qt images

Generated artifacts are under `target/form-field-implementation/` and are intentionally not checked in:

- [Shared family — light](../../target/form-field-implementation/family-light.png) / [dark](../../target/form-field-implementation/family-dark.png)
- [IPv4 — light](../../target/form-field-implementation/ipv4-light.png) / [dark](../../target/form-field-implementation/ipv4-dark.png)
- [IPv6 — light](../../target/form-field-implementation/ipv6-light.png) / [dark](../../target/form-field-implementation/ipv6-dark.png)
- [Narrow network form — light](../../target/form-field-implementation/network-narrow-light.png) / [dark](../../target/form-field-implementation/network-narrow-dark.png)

Use the [manual fixture instructions](../../tests/manual/README.md) to regenerate with the packaged fonts. The original HTML diagrams remain design mockups, not these implementation screenshots.
