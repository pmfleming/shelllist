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

`tests/qml/tst_wifi_scanner_contrast.qml` renders the actual packaged button
source over black/white camera substitutes, checks pixels and contrast in all
states, and exercises native keyboard/disabled behavior. This is not a hardware
camera or physical-screen accessibility acceptance test.
