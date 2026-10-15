# Shelllist QR scanner patches

The `wifiQrScanner` package keeps KDE Qrca's camera, decoding and NetworkManager
workflow. It is built from the deployment's pinned KDE package; patches have
been built against Qrca 26.04.3.

- `remember-network.patch`: each result sheet starts with Remember network on.
  Explicit off uses a new volatile profile, disables autoconnect, marks secrets
  NOT_SAVED, and does not update an existing saved profile. Forget remains a
  separate action; opting out does not erase earlier saved credentials.
- `scanner-contrast.patch` and `ScannerButton.qml`: opaque high-contrast actions
  for camera/light/image selection, Connect, Copy and image dismissal. The same
  actions are presented in an opaque, wrapping scanner toolbar rather than
  transparent generated action buttons. No decoding or connection changes.

The scanner's dark button palette is intentionally independent of the preview,
image and application theme: text is at least 4.5:1 and the keyline at least 3:1
against its own fill. Normal, hover, pressed, checked, disabled and keyboard-focus
states retain readable text and at least 44px height. Native button activation,
action capabilities and accessible labels remain intact.

The dedicated scanner button paint/contrast/native-activation suite was removed
in the [test pruning review](../../tests/test-pruning-current.md). The palette
and activation contract above is unchanged, but its per-state rendered evidence
is no longer retained. The install/startup check below does not replace camera,
contrast, keyboard or physical-screen accessibility acceptance.

The package's install check now runs `tests/check-qrca-startup.py` against the
**complete installed application** on a private D-Bus session, offscreen, without
camera/network access. It requires the scanner page's completion marker and
rejects component/type/property errors. This catches the deployed white screen
caused by assigning Flow's read-only `implicitHeight`; Flow now uses its own
implicit size. Existing closed Kirigami OverlaySheet binding warnings are not
component-load failures. Hardware camera/QR acceptance is still separate.

To repeat safely outside a Nix build (requires `bwrap` and `dbus`):

```sh
python3 tests/check-qrca-startup.py /nix/store/…-qrca-26.04.3/bin/qrca
```

The `--isolated` option is reserved for the Nix build sandbox. Do not use it to
bypass isolation on a desktop session.
