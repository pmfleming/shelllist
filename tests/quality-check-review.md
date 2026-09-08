# Review of previously skipped quality checks

## Parser oracle — valuable, enabled

Both Qt `qmldom` and tree-sitter now inspect every analyzed QML file. The initial
399 disagreements exposed inconsistent oracle counting and genuine Lens gaps:
`Component` factories were treated as attached groups, `Behavior on ...` objects
were missed, and `PropertyAnimation.property` assignments were mistaken for
property declarations. Lens now normalizes equivalent AST constructs, reports
count disagreements as warnings, and has regression tests. Both oracles agree
with the corrected parser on the project.

## qmlformat — valuable, enabled

Applied Qt 6.11 formatting to 235 authored files without import sorting or
attribute reordering. The QML tests and selected Nix checks passed afterward.
Existing Quickshell exit-signal lint annotations needed scoped block comments so
the formatter would not move them off the relevant handler.

26 drift reports remain deliberately visible: 14 generated JavaScript files and
12 files with preexisting user edits. Generated files should follow their
TypeScript/protocol generators, not be hand-edited. Format the other files after
their edits have been reviewed. No quality threshold was relaxed.

## CMake build — not applicable; Nix build checks are valuable

This project has no CMake build. Enabling a CMake command would only test the
wrong build system. Ran the actual Nix checks:

```sh
nix build --no-link \
  .#checks.x86_64-linux.qmlTests \
  .#checks.x86_64-linux.qmlLint \
  .#checks.x86_64-linux.packagedImports \
  .#checks.x86_64-linux.applicationResources \
  .#checks.x86_64-linux.typescript
```

The first sandboxed test build found a weather-test import that assumed a
checkout-only directory. It now imports through the packaged QML module; the
five selected checks pass. This is not a claim that every flake check or the
complete daemon bundle was built. Lens's CMake-specific slot remains skipped.

## Execution coverage — valuable, partial observations now collected

`tests/profile-qml.py` runs the real QML tests through Qt's profiler and emits
`target/profiling/coverage.json`. Lens consumes the native observation format
without pretending it is Cobertura statement/branch coverage. Object creation,
binding execution and signal-handler locations are kept distinct; compilation
alone never counts as execution. Source hashes reject stale observations.

The first run identified seven unobserved high-risk components. New behavioral
tests cover clipboard edit/reset state, Bluetooth adapter draft isolation, and
solar-time presentation, exercising four of those components. The remaining
three are `PopupWindowHost`, `shell/shell.qml`, and `SurfaceRegistry`: meaningful
coverage requires a separate shell/window/compositor scenario, not simulated
hits. The latest suite observes 183 of 266 QML files; absence of observations is
not proof of dead code or a numerical branch-coverage result.

## Runtime performance — valuable, scoped profiling now collected

The same run writes `target/profiling/runtime.json` and preserves the raw Qt
trace at `target/profiling/tests.qtd`. Durations are converted from nanoseconds,
and reports retain Qt/platform provenance and a source manifest. Lens now
aggregates large traces in linear time without argument-limit overflows.

A roughly 24 ms creation hotspot pointed to synchronous Bluetooth battery
artwork loading. Artwork now loads asynchronously, with a test verifying both
that policy and eventual image readiness. The subsequent trace no longer ranked
it as the dominant creation hotspot. This is not a controlled frame-rate claim.

Limitations are explicit:
- Tests run offscreen, with setup/teardown and profiler overhead included.
- No display frame-time/FPS assertion is made. No product-specific performance
  budget is configured: this is exploratory profiling, not a performance gate.
- Qt 6.11's JavaScript profiler misattributed functions across the test runner's
  QML engines (including attributing test waits to trivial property bindings).
  Those suspect events are not published. Binding, creation and signal-handler
  events remain available. Per-file profiling also encountered truncated traces
  on fast process exit and was not accepted as passing evidence.

## Reproduction

From the repository, in its Nix development environment:

```sh
python tests/test_profile_qml.py
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config qmlqualitylens.config.json
```

Build Lens first with `npm run build` in `../qmlqualitylens`. The profiling
runner also requires Python 3 (available in the environment used for this run).
Reports are under `target/qmlqualitylens/`; raw profiler data is local, generated
output. The overall contract remains `warn` because newly enabled checks expose
remaining formatting/coverage review work, not because tests or Qt lint fail.
The heuristic score is now 86 rather than 87: corrected parser coverage and
formatter-driven source layout make that score change non-comparable to the old
measurement alone.
