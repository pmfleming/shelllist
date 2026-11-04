# Five ranked quality improvements — 2026-11-04

Baseline: `b0d9ddd`, the requested commit of all incoming work. The existing
configuration and local QMLQualityLens 0.5.0 evaluator are unchanged. Full static
reports and per-step native logs are under ignored `target/quality-next-five/`.

Ranking weighs measured complexity, consumer reach, duplicated policy, ownership
risks and available native regressions, rather than complexity alone:

1. Share bridge/socket response validation and close the bridge's malformed-reply
   acceptance path. Socket receive is the leading handwritten cognitive hotspot.
2. Flatten shared event routing while retaining subscription and generation fences.
3. Flatten clipboard receipt dispatch without weakening uncertain-operation handling.
4. Store unpublished notification app rows and their cursor as one staging value.
5. Reduce duplicate update-history capture policy in the existing window owner.

## 1. Shared transport response validation

`JsonlRouting.responsePayloadValid` now owns the payload contract used by both
the socket and bridge. The bridge rejects malformed correlation/payloads before
reply delivery or health reset, using its existing configurable protocol-error
recovery. Socket wire-ID admission, route checks, retained uncertain credit and
one late resource acknowledgement retain their owners and ordering. A late
resource is classified once rather than through duplicated uncertainty checks.

The real Qt bridge suite now rejects seven malformed shapes and checks that
none acknowledges work or resets retry health. Removed its one-row startup data
provider and the permanently false branch it left behind; the same drain/reopen
journey remains. Bridge: **11 passes**; socket: **24 passes**; zero failures/skips.
Changed-file strict QML lint and `git diff --check` pass. These are deterministic
transport fixtures, not native socket/hardware or rollout evidence.
