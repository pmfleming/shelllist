# Bar media shortcuts — validation

2026-10-28, based on Shelllist `59a3ca0`.

`tests/qml/tst_media_chip.qml` now instantiates the production
`shell/MediaShortcuts.qml` beside the real bar/controller. Only compositor
registration and daemon transport are substituted. Registered `pressed` signals
and actual pointer clicks must submit identical native player IDs, operations and
seek offsets. Tests retain editor focus/drafts, reject unavailable/capability-denied
commands, follow active-player replacement and forbid optimistic playback or retry.

Final checks, under the existing orchestration check lock and private HOME/XDG,
absent host bus/compositor endpoints and offscreen/software Qt:

- Full actual Qt: **667 passed, zero failed, one existing renderer skip**.
- Focused MediaChip: **14 passed, zero failed, one renderer skip**.
- Full strict QML lint and generated-contract checks pass.
- `python3 tests/review-panel-ui.py --base HEAD`: zero numeric-role/wrapper prompts;
  the new shortcut component has no visual geometry or field stops.
- `git diff --check` passes.

The initial negative-response case exposed Qt's `ignoreWarning` severity limit:
`console.error` is critical, not a warning. The fixture now permits only its exact
intentional `media-play-pause-<id>` / `fixture failure` diagnostic, asserts the
backend error and verifies no retry; all other diagnostics still fail the test.

Logs: `/home/laufan/Projects/shelllist-orchestration/20261027T203355Z/tasks/coordinator-media-shortcuts/`
(`qt.txt` retains the initial failure; `final-qt.txt` and `final-checks.txt` are the
passing replay). No daemon/player effect, live binding change or service restart
was performed. This is not physical media-key/compositor or package acceptance.
See [the contract](../contracts/bar-media-shortcuts.md) and README for binding setup.
