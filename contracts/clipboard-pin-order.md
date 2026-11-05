# Clipboard pin ordering and divider

The clipboard service orders matching history by acknowledged favorite state
(pinned first), then recency descending and stable entry ID. It applies this
ordering before pagination, for both browsing and search. Old pins therefore
appear before even the newest unpinned entry. Pinning does not change the current
clipboard item; unpinning returns an entry to its ordinary recency position.
Search still excludes pins that do not match. Existing revision-bound cursors
and mutation acknowledgements remain authoritative.

Shelllist preserves the native page order without frontend sorting, optimistic
pin changes, or loading all history. Provider metadata supplies a flat
`resultSection` role through the shared keyed model. The shared chooser exposes
Qt's native ListView sections. Clipboard shows one `ListSectionDivider` before
ordinary history when a pinned group precedes it. Empty lists, all-pinned lists
and lists without pins have no divider. The boundary also works when the first
ordinary entry arrives on a later page.

The divider is passive, uses shared spacing/border roles and is excluded from
result counts, selection indexes and editable traversal. Arrow navigation crosses
directly between entries; copy/paste, selection retention, pin guards and history
cursor ownership keep their existing behavior. Shared UI owns its one-pixel line.

Evidence: `tests/qml/tst_clipboard_pins.qml` exercises native paging, grouped
geometry, keyboard selection and copy identity; the sibling clip-daemon's
`tests/turso_storage.rs` covers real database ordering across pages, search,
restart and unpinning, while `tests/api.rs` covers owner-scoped cursors.
