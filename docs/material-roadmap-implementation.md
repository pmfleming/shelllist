# Material roadmap implementation

## Item 2 — search bar

Chooser search uses a 56px Surface Container High pill, a 16px native editor,
primary caret/leading-icon focus feedback, a live filtered-result count and
embedded surface actions. Form inputs keep their outlined frames. Native query
selection, printable-key continuation, IME ownership and guarded Alt+Enter are
unchanged. Progress, errors and domain status remain in the footer rather than
being discarded in favor of a count; empty footers collapse.

Validation: strict lint for changed shared components and the native Qt suite,
including search selection, guarded pointer/accessibility actions, empty counts,
constrained header bounds and stable dimensions across work-area sizes.
