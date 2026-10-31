# Wi-Fi credential ownership

For visible personal and WEP networks, Connect starts `wifi.connectTarget`
without a password. This applies to both new and saved networks. Shelllist must
not display a speculative pre-activation password form: only an outstanding
NetworkManager SecretAgent request opens the network credential dialog.

The dialog answers `wifi.secret.provide` using that request's identity; it must
not start another connection. Native cancellation, expiry, ownership checks,
validation and rejection/re-prompt behavior remain authoritative. Accepted delivery
is not proof of durable storage, and credentials are cleared after acknowledgement.

The network detail's Remember network control selects persistent or volatile
activation before Connect. The native request determines whether its credentials
can/must be saved; answering a temporary request must not change that policy.
NetworkManager is the sole durable credential store, not Shelllist or a keyring.

Enterprise identity/trust setup, hidden-network configuration, explicit saved
credential edits and QR/CLI-supplied credentials retain their separate purposes.
The removed `network-password` form must not be restored as a fallback after a
terminal activation failure.

Requires coordinated deployment with nm-daemon's password-free visible personal/
WEP profile builder. Older daemons may reject a new secured network without an
upfront password; do not deploy the frontend change alone.

Regression owners:
- `tests/qml/tst_wifi_operations.qml`: real Connect input, no speculative prompt,
  native reply without reactivation, temporary/remembered and personal/WEP cases.
- `tests/qml/tst_wifi_prompt.qml`: request-owned retention and acknowledgement.
- nm-daemon `nm::wifi_settings::tests`: password-free WPA/SAE/WEP builders and
  preservation of explicit password input.
- nm-daemon `daemon_secret::activation_tests`: new temporary/remembered activation
  through exported SecretAgent callbacks on a private bus.

These tests do not establish physical Wi-Fi or cold-boot persistence acceptance.
