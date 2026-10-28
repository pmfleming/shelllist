# Control-queue cleanup repair — current-main integration

2026-10-28, baseline Shelllist `683b519`. This closes the shared-control cleanup
bug, not the entire socket migration, startup policy or default rollout.

## Scope and provenance

Ported the shared admission, completing-request identity and resource-cleanup
implementation from work-branch `84baa23` (including `9d86d1d`, `c10063b`,
`d8a1da3`, `cf70a89`, `35d2cca` and the narrowed UNSENT proof in `84baa23`). This is
not a blanket branch merge. The generated result-schema seam/runtime, producer
changes and unrelated clipboard process/paste journeys are not included.

Reviewed the resource ledger, session routing, socket admission and physical
retirement paths against current main. Added a detached-release/full-control
regression and ported only the native `control` probe into the existing clipboard
fixture. Preserved current Agenda/Calendar and all domain safety/editing code.

Contracts: [cleanup](../contracts/subscription-cleanup.md),
[admission](../contracts/shared-socket-admission.md).

## Failure and repair

Fresh actual Qt BEFORE on current main:

```text
DaemonSubscriptionCleanup::test_renewalRetainsExactResourceThroughUnsent
2 passed, 1 failed
verify(backend.renewBaseSubscription()) returned FALSE
Error: UNSENT: full controls
```

The old session forgot the native subscription ID before a cancellation could be
admitted and recovered the whole session on local pressure. Now a bounded ledger
retains the exact owner/route/resource independently of the view. Definitely
never-written cleanup can be retried with a fresh attempt ID; dispatched
uncertainty remains charged until exact acknowledgement or physical retirement.
Reserved control capacity, queued age/withdrawal and immutable wire identities
prevent data/ordinary-control saturation from discarding cleanup or replaying work.
Late/invalid receipts never restore view authority or borrow another resource ID.

The first combined Qt run retained **620 passes / 35 failures / one skip**.
The failures exposed incomplete positive subscription receipts in shared/domain
fixtures (missing protocol/version), not a reason to weaken production validation.
The shared fixture now captures the requested protocol/version, acknowledges
subscriptions using the common native envelope and returns exact cancellation or
raw framework release receipts. Bluetooth, Wi-Fi and clipboard tests use this
helper, including their retired-receipt vectors. Existing assertions remain.
A subsequent full run passed 655/0/one skip; the added detached-release case brings
the final result to 656/0/one skip.

## Final executable checks

- **Full actual Qt: 656 passed, zero failed, one existing renderer skip.**
  Includes cleanup saturation/expiry, detached and late registrations, uncertain
  outcomes, invalid/wrong-owner receipts, bounded record admission, generation
  retirement, socket framing/correlation and reentrant request-policy completion.
- Full strict QML lint and generated-contract checks pass. No generated binding,
  schema, native limit, dependency lock or test expectation was weakened.
- Private real Quickshell full-control probe passes twice against the current
  frontend: **16 native controls held, 15 queued controls expired, one local
  overflow, four distinct retired subscriptions cancelled exactly once, two native
  owners with healthy logical/native peers, zero fake effects**. No pressure-induced
  owner churn or effect replay. This uses production shared routing and real sockets,
  not the deterministic Qt transport substitute.
- Private native control-deadline probe passes: actual owner EOF occurs before the
  delayed positive completion; retained native work finishes cleanup while an
  independent peer stays healthy. A late resource receipt is not free slot credit.
- `git diff --check` passes.

All checks use the existing orchestration shared lock, private HOME/XDG, absent
host bus/compositor endpoints, offscreen/software Qt and outer deadlines. Native
constructors and cleanup were inspected: in-memory backend/isolated settings,
private D-Bus with no host activation directories, cleared child environments,
owned unreaped process-group cleanup, no Ringboard or host input/clipboard helper.
No live services, user data, installed configuration or desktop state were changed.

## Commands and provenance

Evidence root (original failures are retained):

```text
/home/laufan/Projects/shelllist-orchestration/20261027T203355Z/tasks/coordinator-control-cleanup/
  before.txt
  after-initial.txt
  after-fixtures.txt
  native-control.txt
  lint-contracts.txt
  final-qt.txt
  final-checks.txt
```

Qt reproduction from Shelllist, inside the private shared-lock check environment:

```sh
tests/run-qmlquality-tests.sh -input tests/qml/tst_daemon_subscription_cleanup.qml \
  DaemonSubscriptionCleanup::test_renewalRetainsExactResourceThroughUnsent -o -,txt
tests/run-qmlquality-tests.sh -o -,txt
tests/run-qmllint.sh
node tests/check-generated-contracts.js
```

Native replay used the existing inspected worker fixture binary, **not a newly
built or installed producer main**:

```text
clip-daemon fixture HEAD: 4ef73ecac0dbc6883e358ca051aef933f2a1cf39
framework fixture HEAD:   f2425656242267b9c7ef6d470f1526d10a975949
binary: tasks/01-subscription-cleanup/worktrees/clip-daemon/target/debug/deps/clip_daemon-0b18cc51cdb28960
binary SHA256: 49af690f44f037e04a8fbde90cc28a17380a6e4fdb505af199a89186703f8d8d
Quickshell: 0.3.0
Quickshell SHA256: 5ff1892ae380a2630a79e1caf3cfbc111309bfc878cd79415aeaeab7d020c980
QtTest/Qt: 6.11.1
```

The binary hash matches the worker's retained quality replay. With
`SHELLLIST_SOURCE` pointing to this frontend and `SHELLLIST_QUICKSHELL` to the
qualified executable, invoke only these exact safe tests under the shared lock:

```sh
"$binary" --exact daemon::socket::tests::process::control::native_full_control_cleanup_retains_exact_resources_and_healthy_peers --ignored --nocapture
"$binary" --exact daemon::socket::tests::process::control::native_control_deadline_retires_owner_before_late_positive_completion --ignored --nocapture
```

The final combined check used a 360-second outer deadline; native-only replay used
180 seconds. The producer fixture source remains on its work branch, not integrated
into sibling main by this frontend commit. No blanket ignored-test suite was run.

## Limits

The worker's historical partial Lens findings/coverage remain historical; this
integration adds source review and fresh functional/lint checks, not a new complete
Lens certification. No matched-family Nix build, packaged-main acceptance,
cold-start/rollback, sustained-load or performance claim is made. The existing
Date.now/Qt Timer clock-source limitation and unknown-resource retention are
explicit in the contracts. Bridge defaults and socket flags are unchanged.
