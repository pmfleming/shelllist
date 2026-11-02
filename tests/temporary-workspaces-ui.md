# Stage 4: QML controls

Workspace chips render the Rust monitor projection. Active-chip reveal measures
delegate bounds; the fixed add button is outside the viewport. The bar maintainer
owns the existing compact geometry. All workspace targets now use the same
32px icon-only width; origin labels and IDs remain accessible. Pointer
commands accept only the left button; accessible descriptions expose shortcut
names. Selection changes only with observed compositor state.

Applications exposes Alt+O/current and Alt+N/new, preserves Shift+Enter/default,
and provides Uncategorized plus a shared ToggleRow for the independent preference.
The shared FieldRow, navigation and transaction implementation remains in use.
Transport recovery reads the durable operation ID; it never resubmits a launch.

Validation on 2026-11-02:

- Applications action suite: 28 passed.
- Applications settings suite: 4 passed.
- Workspace strip suite: 3 passed, including fixed-button, overflow reveal,
  mixed delegate widths and right/middle-button rejection.
- Strict QML lint: passed.
- Panel UI review: one shared ToggleRow composition prompt, accepted by the
  Applications maintainer because this is the existing editable switch family.
  No panel-local control wrapper or smaller typography was introduced.
- Generated protocol bindings and app reply fixtures come from Rust generators.

These are native Qt interactions with recording transports. Final real-daemon
qualification is separate; no live session deployment is claimed here.

## Icon-only correction, 2026-11-03

Registered the canonical `code`, `description` and `workspaces` Material symbols
so they cannot fall back to literal words. Removed temporary-workspace inline
labels, retained origin icons and accessible names, and clamped stale scroll
offsets when the strip grows wide enough to fit its contents.

The updated Qt fixture uses the real category icon names, verifies rendered
glyph widths and non-overlapping targets, and retains overflow/active reveal,
fixed-add and left-button-only coverage. Four checks pass at 1× and 1.25× scale.
Strict QML lint passes. Panel review reports zero changed-line or wrapper prompts;
the existing bar geometry is reused rather than introducing new size overrides.
