# shelllist

Quickshell experiments and UI components for desktop menus.

The current project focus is a Hyprland-friendly Wi-Fi/network popup backed by the local `nm-daemon` NetworkManager adapter. Shelllist owns the QML interface, window behavior, and user interactions; `nm-daemon` owns NetworkManager behavior and exposes the JSON `nm-api` protocol over a session D-Bus API.

## Current status

- Main app: `shelllist-wifi`, a Quickshell Wi-Fi chooser.
- Default mode: one resident, monitor-aware popover toggled through Quickshell IPC, Waybar, or Hyprland's global-shortcut protocol.
- Optional mode: an explicit one-shot floating window for development/fallback use.
- Backend: the pinned `pmfleming/nm-daemon` flake input; sibling-repository development uses a Nix input override.
- Target platform: `x86_64-linux` with NetworkManager and Quickshell.

## Usage

Start or toggle the default resident popup with Nix:

```sh
nix run
```

While developing against an unpublished sibling `nm-daemon` checkout, override the portable pinned input:

```sh
nix run --override-input nm-daemon path:../nm-daemon
```

Run the explicit floating fallback once the package is on `PATH`:

```sh
shelllist-wifi floating
```

The resident process can also be controlled explicitly:

```sh
SHELLLIST_WIFI_MODE=popover nix run
# or explicitly:
nix run .# -- toggle
```

Popover commands are:

```sh
shelllist-wifi daemon   # ensure the Quickshell popover daemon is running
shelllist-wifi toggle   # toggle the popover
shelllist-wifi open
shelllist-wifi show     # alias for open
shelllist-wifi hide
shelllist-wifi status   # print visible or hidden
```

Waybar can use `shelllist-wifi toggle` for `on-click` once the package is on `PATH`. Popover mode keeps one Quickshell process alive and controls a focused-monitor `PanelWindow` through IPC target `wifi`. Hyprland can invoke its registered shortcut directly:

```ini
bind = SUPER, N, global, shelllist:wifi
```

## Wi-Fi features

Shelllist currently supports:

- cached network snapshots with Shelllist-owned cache refresh while the Wi-Fi UI is visible;
- active Wi-Fi status, IP/connectivity detail display, and selected-network details;
- connection to saved, open, password-protected, hidden, and supported enterprise networks;
- asynchronous `wifi.connect` progress/completion events by `request_id`;
- NetworkManager SecretAgent prompts through `wifi.secret` events;
- optional keyring saving with persistence feedback and explicit prompt cancellation;
- disconnecting Wi-Fi;
- saved-profile actions: disconnect-and-forget, toggle autoconnect, toggle randomized MAC, and toggle hostname sending;
- an advanced saved-profile editor for metered/hidden state, MAC policy, hostname privacy, WPA Personal passwords, IPv4/IPv6 assignment, DNS, DHCP lease metadata, and technical details;
- Wi-Fi QR payload copying for open networks or saved profiles whose secret can be read;
- captive-portal helper launch when requested by the UI or suggested by the backend.

Shelllist is the sole owner of automatic captive-portal presentation. It opens one plain-HTTP page only after a successful `wifi.connect` result reports captive-portal connectivity. An active Wi-Fi link is labelled **Sign in required**, **Limited connectivity**, or **No internet access** until NetworkManager reports full connectivity; **Connected** is reserved for full internet readiness. The helper uses a runtime-only Chrome profile, deduplicates automatic opens by network identity plus connect request, and places or focuses its uniquely-classed app window on the workspace where Shelllist initiated the connection. `shelllist-captive-portal --manual --fallback` rotates through additional plain-HTTP probes for manual troubleshooting. Helper journal records include `helper_elapsed_ms` and the first observed window title, allowing browser startup/window-placement time to be separated from a later hotspot redirect; inspect them with `journalctl -t shelllist-captive-portal`.

Forget is a confirmed daemon-owned workflow. For an active network the UI presents **Disconnect & forget**; `nm-daemon` cancels a matching connection attempt, disables autoconnect, confirms deactivation, and removes every saved profile with the selected SSID. Forget removes local NetworkManager state only: a captive hotspot may continue recognizing the device until its network-side login session expires. While a connect request is pending, Shelllist exposes **Cancel** rather than leaving the active connection without an escape action.

Shelllist sends user-entered Wi-Fi secrets through stdin-backed JSON requests only; secrets are not placed on command-line arguments.

## Keybindings

General popup keys:

- Type to filter visible SSIDs.
- `Enter`: run the primary action for the selected network (`Connect` or `Disconnect`).
- `Down` / `Up`: move selection.
- `Right`: open the details pane.
- `Left`: close the details pane.
- `F6`: connect to a hidden SSID.
- `F7`: open Security & Privacy for the selected saved profile.
- `F8`: open IP & DNS for the selected saved profile.
- `Ctrl+Tab`: cycle Network Details, Security & Privacy, and IP & DNS tabs.
- `F5`: refresh cached networks, active status, saved profiles, and start an explicit scan with spinner/progress events.
- `Esc`: close the popup, or cancel an open prompt.

Details-pane hotkeys are available when the details pane is open and the selected network supports the action:

- `C`: connect.
- `D`: disconnect.
- `F`: confirm forgetting all saved profiles for the network; disconnect first when active.
- `I`: open the captive-portal browser helper.
- `S`: copy Wi-Fi QR payload to the clipboard.
- `A`: toggle autoconnect.
- `R`: toggle randomized MAC.
- `N`: toggle sending the device hostname.

## Backend/API boundary

Shelllist starts one `nm-daemon client` process while the UI or an operation is active. Tagged JSONL requests on stdin multiplex D-Bus calls, subscriptions, cancellation and events. D-Bus ownership, NetworkManager behavior, event filtering and cleanup remain in Rust.

The D-Bus endpoint is:

- bus name: `org.laufan.NmDaemon`
- object path: `/org/laufan/NmDaemon`
- interface: `org.laufan.NmDaemon1`

The UI consumes `nm-api` protocol v1 envelopes:

```json
{ "protocol": "nm-api", "version": 1, "ok": true, "data": {} }
```

Current D-Bus methods used by the UI:

- `wifi.networks` with cached-list parameters;
- `wifi.scan`, returning a scan `request_id`;
- `wifi.connectTarget`, returning a connect `request_id`;
- `wifi.secret.provide` for SecretAgent responses.
- `wifi.disconnect`;
- `wifi.profile.operation` for profile details, atomic advanced updates, password reveal, delete, privacy, autoconnect, hostname and sharing operations.

Current event streams used by the UI:

- `wifi.scan`
- `wifi.connect`
- `wifi.secret`
- `wifi.status`
- `network.connectivity`

Cache refresh ownership: Shelllist does not rely on an always-on `nm-daemon-cache-refresh.timer`. While the Wi-Fi UI is visible/in use, it calls `wifi.networks` with `{ "cached": true, "refresh_cache": true }` to show the last cached snapshot immediately and warm the next one in the background. Hiding/unfocusing the popover stops Shelllist's UI-owned refresh loop. Explicit refresh uses `wifi.scan` with `cache: true` and filters `wifi.scan` events by `request_id`.

Status and connectivity are continuous subscriptions rather than polling loops. Closing the UI cancels its scan; closing the JSONL session cancels every remaining session-owned request and subscription.

## Theming and window behavior

The popup uses Nix/Home Manager `SHELLLIST_*` environment values as its single configured theme source, with the Qt/system palette as a portable fallback. It no longer maintains a second asynchronous theme state through `hyprctl getoption`.

Animation behavior:

- Under Hyprland, animations are enabled unless `SHELLLIST_NO_ANIMATIONS` overrides them.
- Outside Hyprland, Shelllist defaults to no animations.
- Set `SHELLLIST_NO_ANIMATIONS=1` or `SHELLLIST_NO_ANIMATIONS=0` to override while testing.

Supported color/radius environment overrides include `SHELLLIST_BG`, `SHELLLIST_SURFACE`, `SHELLLIST_TEXT`, `SHELLLIST_SUBTEXT`, `SHELLLIST_BORDER`, `SHELLLIST_STRONG_BORDER`, `SHELLLIST_ACCENT`, `SHELLLIST_SELECTED`, `SHELLLIST_SUCCESS`, `SHELLLIST_DANGER`, `SHELLLIST_WARNING`, and `SHELLLIST_RADIUS`.

In floating mode, Shelllist performs one Hyprland focus/float/center placement action. In popover mode, it uses a focused-monitor layer-shell `PanelWindow` with namespace `shelllist-wifi` and synchronizes the matching Hyprland layer animation rule. Quickshell's private GlobalShortcut compatibility import is isolated in `WifiGlobalShortcut.qml`.

## Requirements

- A running NetworkManager service.
- A Wi-Fi device managed by NetworkManager.
- User permissions to control NetworkManager connections through D-Bus/polkit.
- A running or D-Bus-activatable `nm-daemon` session service exposing `org.laufan.NmDaemon`.
- The pinned `nm-daemon` input, or a sibling checkout supplied with `--override-input nm-daemon path:../nm-daemon`.

## Visible-network connection probe

Shelllist exposes the `nm-daemon` parity probe so the UI repo and backend repo use the same destructive connection test. By default it is a dry run that inventories visible networks only:

```sh
nix run .#connectParityProbe
```

To actually attempt every selected visible network, pass `--execute` explicitly:

```sh
nix run .#connectParityProbe -- --execute --order alternate --skip-needs-secret
```

The executed probe disconnects between attempts and writes logs under `$XDG_STATE_HOME/nm-daemon/connect-parity/<timestamp>`.

## Development

```sh
nix develop
nix flake check --override-input nm-daemon path:../nm-daemon
```

Useful checks:

```sh
nix flake check --no-build --show-trace
out=$(nix build .#default --no-link --print-out-paths)
shellcheck "$out/bin/shelllist-wifi"
portal=$(nix build .#captivePortalBrowser --no-link --print-out-paths)
shellcheck "$portal/bin/shelllist-captive-portal"
shelllist-qmllint wifi/*.qml wifi/networkinput/*.qml wifi/process/*.qml
node tests/check-ip-validation.js wifi/networkinput/IpValidation.js
```

The Wi-Fi UI entry point is `wifi/shell.qml`. Reusable IPv4/IPv6 address and prefix controls live in the `wifi/networkinput` QML module. Their validator distinguishes acceptable, intermediate, and invalid editing states so incomplete addresses remain editable without being saved or immediately presented as errors.

The JSON boundary with `nm-daemon` is pinned by `contracts/nm-api-ui-contract.fixture.json`. `nix flake check` regenerates the fixture, validates the frontend method shapes, regenerates the used method and stream entries in `wifi/NmApi.js` from `nm-daemon debug protocol-registry`, and lints every QML source; any drift or static-analysis failure fails the check.
