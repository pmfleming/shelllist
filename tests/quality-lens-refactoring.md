# Quality Lens refactoring campaign

Baseline: `606b93631ada767d8ca69470a733f2c5651d9a2c`.
Static comparisons archive both commits and use one frozen evaluator and unchanged
`qmlqualitylens.config.json`. Scores are advisory, not behavior or productivity proof.
Raw local evidence is in the sibling Lens checkout's `target/shelllist-campaign/`.

## Remove unused internal presentation/state

Removed the unused `ApplicationPresentation.cpuText` / `memoryText` functions and
their private number helper. Application resources use their existing resource
presentation owner instead. Removed VPN's write-only `connectingUuid`; the request
ID still owns connection cancellation/completion. Tracked-source and test searches
found no consumers of these internal names. No provider/model API, IPC entry point,
compatibility behavior or test owner was retired.

Qt 6.11.1, offscreen/software, matching qtsvg plugin: baseline and this change each
pass **419 checks, zero failures, one existing renderer skip** (counts include
lifecycle hooks). No tests were changed. Initial baseline SVG failures were resolved
by supplying the environment's matching SVG plugin, not by suppressing assertions.
Hardware mutations, live compositor, IME and human accessibility remain untested.
