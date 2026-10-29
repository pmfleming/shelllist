# Application detail collection bounds

Application details retains its shared read-only `DetailFlickable`, inset cards,
workspace/title alignment and command-only interaction. Window and desktop-action
collections now use the shared `CollectionPager` and keyed models: at most eight
window rows and eight desktop-action rows are instantiated, regardless of the
application's collection sizes. Workspace measurement also visits only that
window. Hidden paging headers are lazy, rather than eagerly creating invisible
command controls for empty/small collections.

Previous/Next commands are available through the shared Alt+J menu, not extra
field Tab stops. Every native window/action remains reachable; paging does not
launch, focus, close or mutate application settings. Page changes reveal the
collection heading, and stable per-application anchors restore through tab and
application switches using shared chooser presentation memory.

Delegate keys include both application and child identity. Application ownership
comes from that keyed row's payload, never a mutable page index. At invocation,
window and desktop commands resolve their current native action by child ID and
recheck selected-app identity, availability and operation guards. Pending
operations disable page replacement. Native acknowledgement, operation progress,
status recovery and close-window outcomes are unchanged.

`tests/qml/tst_application_actions.qml` covers 60/512 windows and 128 desktop
actions, delegate bounds, native Alt+J paging, final-page reachability, keyed
incoming insertions, per-app/tab restoration, original native target dispatch,
read-only traversal and pending-operation guards. Existing tests retain operation
admission, revisions, uncertain outcomes and no-replay checks. Timing captures
remain non-gating; these tests use recording transports and do not close or launch
real applications.
