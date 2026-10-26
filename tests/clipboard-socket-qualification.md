# Clipboard socket qualification — 2026-10-26

This closes the five-step clipboard implementation/qualification sequence, **not**
the wider migration or approval to change defaults. The bridge remains default;
`SHELLLIST_CLIP_SOCKET=1` is explicit, independent opt-in. D-Bus stays supported.
No deployment, push, live service restart, hardware/clipboard publication or real
cache deletion was performed.

## Tested implementation

| Step | Producer | Frontend |
| --- | --- | --- |
| 1. Asynchronous operation ownership | `dce191f` | — |
| 2. Read-only recovery / ordering | `1fb1f07` | `110986b` generated contracts |
| 3. Shared direct ingress | `c18c018` | — |
| 4. Opt-in, recovery and private acceptance | `a017338` | `0b2c848` |
| 5. Matched release qualification | Evidence recorded here; no default switch | Evidence recorded here |

Prerequisite ownership: producer `aeaed46`, frontend scope `51b0d05`. Shared
framework: `563e7f9`. Other sibling inputs were unchanged: BT `3e0ecb4`, NM
`0396f00`, app `bb013f1`, bar `cca6041`, update worker `7c3432f`.

## Results

| Gate | Result |
| --- | --- |
| Producer all-target/all-feature debug tests | 55 library, five API, one retained-client integration passed; four explicit-only tests ignored (benchmark, two heavy payload cases, native probe) |
| Heavy private payload tests, explicitly invoked | Both passed |
| Actual native Quickshell 0.3.0 probe, explicitly invoked | Both ordinary and large-payload subcases passed |
| Rust formatting and all-target/all-feature Clippy | Passed, warnings denied |
| Actual Qt suite | 429 passed, one existing renderer skip |
| Strict QML lint / generated contracts / offline clipboard parity | Passed |
| Surface catalog / build-input alignment / advisory panel review | Passed; no new geometry or role exceptions |
| Sibling-source preflight | Passed, no overrides or bypasses |
| Nix `clipDaemonContract` | Passed; release package ran 57 library + five API + one retained-client tests, including both heavy payload cases |
| Nix `qmlTests` | Passed: 429 / one existing skip |
| Nix `buildInputs` | Passed: Rust 1.95.0, ten locked roots, 46 shared dependencies |

The native probe is a non-default Cargo feature and normally ignored; it is not
counted as part of the release package's ordinary `--include-ignored` checks.

## What the evidence establishes

- Real D-Bus/socket parity and caller isolation; disconnect, foreign access,
  reconnect isolation and accepted work registered after disconnect. The same
  admitted exported service and coordinators serve both transports.
- Owned asynchronous status/terminal retention, read/event ordering, early
  completion, quiet terminal loss and bounded admission. A missing/expired or
  lost-before-ack operation remains unknown; status never repeats the effect.
- Actual Qt fences history/details against initial/reset/lag and older responses;
  malformed watermarks cannot consume a valid cursor. Graceful idle shutdown also
  permits a fresh producer epoch without accepting drained older reads.
- One status read outstanding per consumer, one-second polling and a five-second
  uncertainty deadline. A deadline never launches an additional outstanding read.
  Gaps preserve accepted-work guards; terminal/unknown operations cannot reopen.
  Consumer-local operation tracking prevents a shared peer's receipt from changing
  its work. Private drafts and the captured save-and-paste handshake remain owned.
- Real Quickshell shared routing/recovery with two consumers, repeated reads,
  native history invalidation racing an older reply, independent subscription
  renewal, consumer release, healthy peer read and disconnect before listener
  shutdown. The producer is in-process, private-bus and read-only gated, with
  in-memory history and isolated settings; the child has private HOME/runtime,
  nonexistent bus addresses and a cleared inherited environment.
- Exact 128 MiB request framing (excluding LF) and exact 32 MiB response framing
  (including LF). One-byte-over input cannot execute the fake deletion; oversized
  output retires only its owner. A truly non-reading socket triggers cleanup of
  its fake operation while the healthy owner's work remains live. That case uses
  a shortened 100 ms write deadline, not a production timing assertion.
- Native transport of a 16 MiB control-character fixture parameter (96 MiB escaped
  JSON) and a near-32 MiB UTF-8 response. These are read-only synthetic framing
  inputs, not real clipboard content or a maximum-size publication. Clipboard's
  bounded UTF-16 reservation matches its larger record allowance; other daemons'
  budgets are unchanged and the producer ceiling is not raised.

## Remaining gates

- BT/NM lifecycle and remaining stream recovery rows in the
  [stream matrix](../contracts/unix-jsonl-stream-matrix.md).
- Sustained mixed-load/bounded-memory measurements and matched release latency,
  RSS/PSS/private-memory comparisons. Passing release tests is not a benchmark.
- Actual clipboard daemon OS-process kill/restart and installed-session tests.
  Listener/connection tests and an in-process native fixture are not OS-crash proof.
- Full packaged cold-start/activation, service ordering, upgrade/mismatch and
  non-replaying rollback acceptance. Socket opt-in needs an already-running,
  matching producer; no automatic bridge fallback is introduced.
- Separate authorization for default rollout and live desktop/hardware acceptance.
  There is no durable operation journal, reconstructed missed history or inferred
  paste success. Owner cleanup is cancellation, never rollback of published content
  or already injected input.

## Reproduction and local logs

Native and heavy-payload commands: [tests README](README.md#clipboard-native-opt-in-and-recovery).
Producer isolation: `../clip-daemon/docs/transport-ownership.md` from the repository
root. Use current matched source snapshots for Nix:

```sh
# From shelllist, inside its development shell:
../daemon-framework/tools/local-build preflight .
for attribute in clipDaemonContract qmlTests buildInputs; do
  ../daemon-framework/tools/local-build build \
    --attr checks.x86_64-linux.$attribute . --no-link --print-build-logs
done
```

Temporary logs (not durable evidence artifacts): `/tmp/clip-step4-rust.log`,
`/tmp/clip-step4-final.log`, `/tmp/clip-step4-native.log`,
`/tmp/clip-step4-payload.log`, `/tmp/clip-step5-nix.log`. The payload log records
successful heavy cases followed by an initial unnecessary-allocation Clippy
finding; that was fixed, and strict Clippy passed in the final Rust log. No failed
gate is being treated as a pass.
