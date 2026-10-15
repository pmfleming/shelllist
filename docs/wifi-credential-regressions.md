# Wi-Fi credential and QR regression acceptance — 2026-10-14

## Manual Connect follow-up

Saved-profile Connect now activates first; only a live native SecretAgent request
opens a credential form. Terminal failures no longer launch a second password
transaction. Expiry clears drafts, late receipt/retirement is correlated, and
activation retirement preserves native terminal status. **Update credentials**
(Alt+U) explicitly opens the existing versioned personal-password Security editor;
it does not invent enterprise/WEP replacement fields or reconnect automatically.

The actual Qt Connect-button regressions cover success, missing/rejected secrets,
timeout and cancellation, plus the explicit editor command, local credential
expiry and Remember OFF for new/saved networks. The sibling daemon's private-bus
suite exercises ActivateConnection -> exported GetSecrets, available credentials,
interactive entry, fresh-secret rejection, no frontend, retirement and late replies.
See `../nm-daemon/docs/manual-wifi-activation.md` for deadline and outcome details.
Follow-up validation: **651 Qt checks passed, one existing skip**; strict QML lint,
API contract and generated-binding checks pass. **133 Rust tests passed, four
ignored**; Clippy and Rust format checks pass, and the real keyring-provider test
passed separately. The historical counts below describe the earlier correction.

Deployment/live comparison still requires approval and a backup connection. No
running service or live connection was changed during this follow-up.

## Scope and commits

1. Credential/keyring recovery: `nm-daemon` fb2475e and Shelllist 6ea15c9.
2. Remember defaults and explicit temporary joins: `nm-daemon` 2a60b2d and
   Shelllist d3fc57e.
3. QR scanner button contrast only: Shelllist 9a306c6. Camera, decoder and
   Qrca-owned connection workflow are unchanged.
4. This regression pass: native persistence/activation tests, acknowledgement
   ordering, packaging of scanner tests and remaining acceptance gates.

Tests use synthetic passwords, fake D-Bus peers and recording UI transports.
No real network activation, password disclosure, service restart or reboot is
part of the automated pass.

## Post-deployment correction

The original pass below missed complete scanner startup and real-provider timeout
behavior. The deployed scanner had a read-only Flow `implicitHeight` assignment;
keyring persistence still blocked password delivery, and timeout Dismiss calls
coincided with GNOME keyring crashes. The original Qrca output below is **not** a
working scanner build.

Corrected validation:

- **634 Qt checks passed**, one existing skip; strict QML lint passes. Actual
  Enter submission exercises all six receipt/delivery/persistence event orders.
  A save warning remains visible after connection success and is cleared only
  by successful saving for the same profile, not another profile's success.
- **122 Rust tests passed**, four ignored (including the separately run
  real-provider test); Clippy with warnings denied passes.
- The complete packaged scanner now passes an isolated offscreen install check:
  `/nix/store/pwlmn0l27s3zhiv1dv1kdi0kgvagwlns-qrca-26.04.3`.
  The same test rejects the old deployed output with the original read-only
  property error. Scanner fix commit: `0ee7d46`.
- Real GNOME keyring 50.0/Gcr 3.41.2 passes live-dialog timeout, repeat/coalescing,
  Escape cancellation, fresh-client secret recovery and provider-exit tests in
  a private bus/display/HOME/network namespace. Synthetic fixture unlock uses
  GNOME's internal test/PAM API; this does not establish real login/PAM behavior.
- The daemon now dispatches credentials before saving, provides a bounded native
  password handoff while the keyring is locked, and never Dismisses a live unlock
  on timeout. Finish an unresolved unlock dialog before retrying saving; expired
  saves are not replayed. Remember remains on by default with explicit opt-out.

No live service restart, camera access, network change or reboot was performed.
The matching provider test instructions and detailed daemon coverage are in
`../nm-daemon/docs/wifi-credential-regressions.md`.

## Original automated evidence (superseded by the correction above)

- `tests/run-qml-tests.sh` with `QML_XHR_ALLOW_FILE_READ=1`: **627 passed,
  0 failed, 1 existing renderer skip**, Qt 6.11.1 offscreen/software. Counts include
  Qt lifecycle hooks, not just independent tests. Fixture file reads must be
  enabled, as they are in the Nix check environment.
- Strict `tests/run-qmllint.sh`: passes.
- `nm-daemon` `cargo test --lib`: **116 passed, 0 failed, 3 existing opt-in
  tests ignored**. `cargo clippy --all-targets -- -D warnings`: passes.
- The patched Qrca 26.04.3 package builds against the deployment's pinned
  nixpkgs revision `8eeec934ae0dbeca3d7868c059568a65c08b2fc3`, including build-time
  QML checking, but without complete scanner startup. Its broken output was
  `/nix/store/9ahaxrcpl379nr1n5jzgh8zspp1ya9lp-qrca-26.04.3`.
- The product Nix Qt check includes `nix/qrca` for the actual scanner button
  component, and the scanner package is also a named flake check. A full combined
  product deployment/rebuild is not claimed by the leaf-package build.

| Regression | Evidence owner |
| --- | --- |
| Enter sends the actual named password while connection is in progress | `tst_wifi_operations` |
| Form stays open until owned acknowledgement; foreign reply is ignored | `tst_wifi_operations` |
| Expired/unavailable request clears secrets and requires explicit reconnect | `tst_wifi_operations`; SecretAgent registry tests |
| Save failure survives delivery → persistence → receipt | `tst_wifi_operations`; other ordering permutations were pruned |
| Remember defaults on; explicit off is propagated and does not leak to a different network | `tst_wifi_prompt`, `tst_wifi_operations` |
| Temporary activation uses native `persist=volatile`, disables autoconnect, and drops cloned UUID | `daemon_connect` and `nm::activate` tests |
| NOT_SAVED flags prevent keyring persistence | `daemon_secret` tests |
| Locked collection unlocks before CreateItem; cancelled/timed-out prompts fail | `keyring` fake-D-Bus tests |
| Saved UUID secret survives a new agent session and changed NM path; noninteractive lookup cannot unlock | `keyring` fake-D-Bus tests |
| Scanner contrast and native button activation | Dedicated per-state suite pruned; no equivalent paint/activation acceptance claimed |

The native tests exposed and fixed a stale `Locked` property-cache read after
unlock. The UI tests exposed and fixed a persistence warning being overwritten
by a later credential acknowledgement. Secret-request expiry now retires its
registry entry before publishing the event, closing the late-reply race.
Only request identity/status/acceptance are added to submission logs; no values
or QR payloads are logged.

## Live acceptance still required after deployment

Build/deploy the matching Shelllist and nm-daemon revisions together; the checked
out sources use protocol v2 and add a separate credential-delivery event.
A source commit alone does not update the running Nix-store applications.

On a spare/test connection, with a recovery network available:

1. Connect by QR with Remember on, confirm actual activation and successful
   password persistence, then reboot and verify reconnection. The login service
   must unlock the desktop keyring for unattended reconnect; autologin without
   a keyring-unlock mechanism still requires explicit unlock. Do not weaken
   keyring encryption or store the login password to bypass this requirement.
2. Lock the keyring and retry. Verify the provider-owned unlock dialog, cancel,
   timeout and successful retry. A connection success must not hide a save
   failure, and a failed save must never be reported as remembered.
3. Enter a password in each ordinary and daemon-requested form; test both Enter
   and the primary button. Leave a request until timeout, then verify that no
   stale submission is reported as successful.
4. Turn Remember off in ordinary, hidden/enterprise and QR paths. Verify a new
   profile is in memory only, autoconnect is off, and it disappears after
   disconnect/reboot. An earlier saved profile must remain unchanged; use Forget
   explicitly if deletion is wanted.
5. Check camera recognition and camera/image toolbar actions on the physical
   display, in both desktop themes and bright/dark video. Automated contrast
   checks do not establish camera reliability, hardware IME behavior or human
   accessibility acceptance.

No live reboot, login/PAM reconfiguration, camera scan or Wi-Fi mutation was
performed during this implementation.
