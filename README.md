# shelllist

Quickshell experiments and UI components for desktop menus.

Shelllist is a Hyprland-focused desktop action center. Its Wi-Fi popup is backed by `nm-daemon`; the staged Bluetooth popup is backed by `bt-daemon`. Shelllist owns QML, window behavior, and interactions while the Rust backends own system integration and policy.

## Current status

- Stable app: `shelllist-wifi`, a Quickshell Wi-Fi chooser.
- Experimental app: `shelllist-bluetooth`, a BlueZ device chooser kept alongside the existing Rofi Bluetooth menu during stabilization.
- Default mode: resident, monitor-aware popovers toggled through Quickshell IPC, Waybar, or Hyprland.
- Optional mode: an explicit one-shot floating window for development/fallback use.
- Backend: sibling `nm-daemon` and `bt-daemon` Git inputs while their current API histories are unpublished; repin both to portable GitHub inputs after publication.
- Target platform: `x86_64-linux` with NetworkManager and Quickshell.

## Usage

Start or toggle the default resident popup with Nix:

```sh
nix run
```

The current development lock uses portable relative references to sibling `nm-daemon` and `bt-daemon` checkouts because the required histories are not published yet. Keep the three repositories in the same parent directory. After those commits are published, restore GitHub inputs; explicit overrides remain available when testing other checkouts:

```sh
nix run \
  --override-input nm-daemon path:/path/to/nm-daemon \
  --override-input bt-daemon path:/path/to/bt-daemon
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

Waybar can use `shelllist-wifi toggle` for `on-click` once the package is on `PATH`. Popover mode keeps one Quickshell process alive and controls a focused-monitor `PanelWindow` through IPC target `wifi`. Hyprland can invoke Wi-Fi's registered shortcut directly:

```ini
bind = SUPER, N, global, shelllist:wifi
```

Run the experimental Bluetooth popup:

```sh
nix run .#bluetooth
shelllist-bluetooth toggle
shelllist-bluetooth floating  # one-shot floating fallback
```

The stabilization binding is `SUPER+M`. `SUPER+B` remains assigned to `rofi-bluetooth-menu` until Shelllist Bluetooth is ready to replace it. In the device list, `Right` opens details and `Left` closes them. `Alt+Tab` cycles Device Details, Audio & Transfer, and Adapter tabs; `Ctrl+Tab` is retained as the network-popup-compatible alternative.

Run and configure the clipboard popup with:

```sh
nix run .#clipboard
shelllist-clipboard --pause       # pause history capture
shelllist-clipboard --private     # pause capture and mark private mode
shelllist-clipboard --resume      # resume history capture
shelllist-clipboard --kept 750    # set the regular-history retention limit
```

Settings-only invocations update `clip-daemon` without opening the popup. A popup action may follow the options, for example `shelllist-clipboard --resume open`. The clipboard UI keeps destructive history clearing behind its icon-only header action and confirmation dialog; pause, private-mode, and retention controls are CLI-only.

## Bluetooth implementation status

The Bluetooth surface provides a keyboard-first device list, filtering, per-adapter power, bounded discovery with request IDs and cancellation, live and recently cached signal strength, standard battery display, and contextual pair/connect/disconnect behavior. It shows the cached list immediately, dims last-known signal after discovery ends, and retains recently found devices long enough to pair instead of collapsing to paired devices. `Right` opens a structured details surface with persistent primary/secondary actions and separate Device Details, Audio & Transfer, and Adapter tabs. Device details always place a device visual above the overview, enrich it with component-battery rings when available, and retain the last observed battery state while a device is disconnected; settings include auto-saved rename, trust, wake, block, capability-gated Fast Pair multipoint and noise-control modes, shared destructive confirmation, service and technical summaries; adapter settings include segmented adapter selection, an auto-saved alias, auto-saved timeout sliders, pairable/discoverable controls, and trust-after-pair policy. The UI communicates only through `bt-api` v1 and opaque device keys; it does not parse `bluetoothctl` output or route actions on MAC addresses. A `shelllist:bluetooth` Hyprland global shortcut is registered alongside the transition IPC command.

Shelllist consumes live Bluetooth, scan, operation, audio, pairing and OBEX subscriptions instead of polling. Authenticated Fast Pair controls are shown only when `bt-daemon` reports the corresponding multipoint or Hearable Controls capability; unsupported devices do not receive speculative controls. Its application-specific daemon pairing agent handles PIN/passkey input and display, numeric confirmation, authorization, cancellation, and timeout prompts without taking default-agent ownership away from Blueman. Device actions use opaque operation request IDs and live lifecycle events, with `Escape` and an advanced-panel button available to cancel active work. Device IDs come from the daemon's private persistent registry and remain stable for BlueZ-resolved identities; unknown unpaired devices with rotating private addresses remain intentionally uncorrelated. The advanced panel reads and switches available A2DP/HSP/HFP codec profiles through the daemon's sanitized native PipeWire API. Live audio subscriptions report sink/source readiness, runtime state, and default-route status without frontend polling. The Audio & Transfer tab can select and send one regular file through daemon-owned OBEX object-push sessions with byte progress and cancellation. A persistent hidden frontend subscription opens a keyboard-first accept/reject prompt for incoming files, which are confined by daemon policy to collision-safe names in Downloads; incoming transfers also report progress and support cancellation.

## Wi-Fi features

Shelllist currently supports:

- cached network snapshots with Shelllist-owned cache refresh while the Wi-Fi UI is visible;
- Wi-Fi radio power control, active status, IP/connectivity detail display, and selected-network details;
- connection to saved, open, password-protected, hidden, and supported enterprise networks;
- asynchronous `wifi.connect` progress/completion events by `request_id`;
- NetworkManager SecretAgent prompts through `wifi.secret` events;
- optional keyring saving with persistence feedback and explicit prompt cancellation;
- disconnecting Wi-Fi;
- saved-profile actions: disconnect-and-forget, toggle autoconnect, toggle randomized MAC, and toggle hostname sending;
- an advanced saved-profile editor for metered/hidden state, MAC policy, hostname privacy, WPA Personal passwords, IPv4/IPv6 assignment, DNS, DHCP lease metadata, and technical details, with directional animation across all three detail tabs;
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
- `Left`: close the details pane while the network list has focus; search-field caret movement is left untouched.
- `F6`: connect to a hidden SSID.
- `F7`: open Security & Privacy for the selected saved profile.
- `F8`: open IP & DNS for the selected saved profile.
- `Ctrl+Tab`: cycle Network Details, Security & Privacy, and IP & DNS tabs.
- `F5`: refresh cached networks, active status, saved profiles, and start an explicit scan with spinner/progress events.
- `Esc`: close the popup, or cancel an open prompt.

`F5`–`F8` are window-scoped, so they remain available when focus is on a details-pane control. Prompt-local keys retain priority while a modal prompt is open.

Details-pane hotkeys are available when the details pane is open and the selected network supports the action:

- `C`: connect.
- `D`: disconnect.
- `F`: confirm forgetting all saved profiles for the network; disconnect first when active.
- `I`: open the captive-portal browser helper.
- `S`: copy Wi-Fi QR payload to the clipboard.
- `A`: toggle autoconnect.
- `R`: toggle randomized MAC.
- `N`: toggle sending the device hostname.

## Provider model

Shelllist normalizes system integrations behind a generic provider/result/action model. Providers expose stable descriptors, map backend values to serializable results, resolve live action state, and execute actions through a central registry. Generic views never inspect provider payloads or call system backends directly. `ResultStore` ranks each update once and synchronizes a persistent keyed `ListModel`, so recurring scan snapshots update/move delegates instead of replacing the ListView model. Wi-Fi and Bluetooth result snapshots omit duplicated action objects because their providers resolve those actions from live controller state at use time.

The current `WifiProvider.qml` adapter maps `nm-api` networks and Wi-Fi operations onto this model without changing `nm-daemon` protocol v1. See [`docs/provider-model.md`](docs/provider-model.md) for the schemas, validation rules, query generations, action dispatch contract, and guidance for application, clipboard, and Bluetooth providers.

## Backend/API boundary

Shelllist starts one `nm-daemon client` process while the UI or an operation is active. Tagged JSONL requests on stdin multiplex D-Bus calls, subscriptions, cancellation and events. D-Bus ownership, NetworkManager behavior, event filtering and cleanup remain in Rust. If the executable or service is unavailable, the shared JSONL client retries with exponential backoff from 1.5 seconds to a 30-second cap; a valid response/event resets the delay, and queued calls cannot bypass it.

The D-Bus endpoint is:

- bus name: `org.laufan.NmDaemon`
- object path: `/org/laufan/NmDaemon`
- interface: `org.laufan.NmDaemon1`

The UI consumes `nm-api` protocol v1 envelopes:

```json
{ "protocol": "nm-api", "version": 1, "ok": true, "data": {} }
```

Current D-Bus methods used by the UI:

- `wifi.setEnabled` for Wi-Fi radio power control;
- `wifi.networks` with cached-list parameters;
- `wifi.scan`, returning a scan `request_id`;
- `wifi.connectTarget` with the daemon-provided opaque network `key`, returning a connect `request_id`;
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

The popup uses Nix/Home Manager `SHELLLIST_*` environment values as its single configured theme source, with the Qt/system palette as a portable fallback. It no longer maintains a second asynchronous theme state through `hyprctl getoption`. Shared `Shelllist.Ui` tokens also define spacing, margins, control and status heights, typography, icons, disabled opacity, motion, and list density so applications do not establish parallel visual constants.

Wi-Fi and Bluetooth derive a bounded `0.82–1.12` density scale from their available height. List/header spacing, search/header controls, status bars, rows, and details content therefore shrink together on short displays and expand together on taller displays. Their shared refresh tile spins and remains unavailable for the full list refresh; status bars report progress as text without duplicating the refresh animation. Modal prompt cards derive their height from wrapped content rather than fixed pixel heights.

Animation behavior:

- Network Details, Security & Privacy, and IP & DNS animate in both directions without exposing off-screen/stale panes while the chooser expands.
- Under Hyprland, animations are enabled unless `SHELLLIST_NO_ANIMATIONS` overrides them.
- Outside Hyprland, Shelllist defaults to no animations.
- Set `SHELLLIST_NO_ANIMATIONS=1` or `SHELLLIST_NO_ANIMATIONS=0` to override while testing.

Supported color/radius environment overrides include `SHELLLIST_BG`, `SHELLLIST_SURFACE`, `SHELLLIST_TEXT`, `SHELLLIST_SUBTEXT`, `SHELLLIST_BORDER`, `SHELLLIST_STRONG_BORDER`, `SHELLLIST_ACCENT`, `SHELLLIST_SELECTED`, `SHELLLIST_SUCCESS`, `SHELLLIST_DANGER`, `SHELLLIST_WARNING`, and `SHELLLIST_RADIUS`.

The shared `PopupWindowHost` gives each application the same floating fallback, focused-monitor geometry, fixed maximum layer surface, centered animated content, IPC lifecycle, focus grab, compositor rules, and per-namespace animation policy. Shelllist-owned prompts and confirmations use the shared themed modal framework; the native `FileDialog` used to choose an outgoing Bluetooth file is intentionally system-themed. In floating mode, Shelllist performs one Hyprland focus/float/center placement action and otherwise leaves placement to the portable compositor fallback. Quickshell's private GlobalShortcut compatibility import is isolated in the shared `ShelllistGlobalShortcut.qml` adapter.

## Requirements

- A running NetworkManager service.
- A Wi-Fi device managed by NetworkManager.
- User permissions to control NetworkManager connections through D-Bus/polkit.
- A running or D-Bus-activatable `nm-daemon` session service exposing `org.laufan.NmDaemon`.
- Sibling `nm-daemon` and `bt-daemon` checkouts containing the locked API histories, or both inputs supplied through `--override-input`.

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
nix flake check
```

Useful checks:

```sh
nix flake check --no-build --show-trace
out=$(nix build .#default --no-link --print-out-paths)
shellcheck "$out/bin/shelllist-wifi"
portal=$(nix build .#captivePortalBrowser --no-link --print-out-paths)
shellcheck "$portal/bin/shelllist-captive-portal"
shelllist-qmllint qml/Shelllist/{Core,Io,Ui}/*.qml qml/Shelllist/Io/process/*.qml bluetooth/*.qml wifi/*.qml wifi/networkinput/*.qml wifi/process/*.qml
node tests/check-ip-validation.js wifi/networkinput/IpValidation.js
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
tests/run-qml-tests.sh
qmlqualitylens measure all --config qmlqualitylens.config.json  # optional static quality report
```

The UI entry points are `wifi/shell.qml` and `bluetooth/shell.qml`. Generic provider contracts, validation, single-pass ranking, keyed incremental ListView synchronization, registry dispatch, and result storage live in the shared `Shelllist.Core` module under `qml/Shelllist/Core/`; shared daemon transport (including bounded exponential restart backoff) lives in `Shelllist.Io`, with Process ownership isolated under its `process/` boundary; shared theming, popup/window behavior, surface behavior, controls, detail cards, toggles, text fields, and modal frames live in `Shelllist.Ui`; `WifiProvider.qml` and `BluetoothProvider.qml` are backend adapters. Frontend-only Wi-Fi helpers are separated by responsibility into `WifiPresentation.js`, `WifiFlow.js`, and `NmApiClient.js`; connection, scan, advanced-profile, network-action, share, and captive-portal flows live in dedicated controller Items rather than the main Wi-Fi controller. Bluetooth device details are likewise split into overview, action, metadata, and adapter-setting sections. Reusable IPv4/IPv6 address and prefix controls live in the `wifi/networkinput` QML module. Their validator distinguishes acceptable, intermediate, and invalid editing states so incomplete addresses remain editable without being saved or immediately presented as errors.

The JSON boundary with `nm-daemon` is pinned by `contracts/nm-api-ui-contract.fixture.json`. `nix flake check` regenerates the fixture, validates the frontend method shapes, regenerates the used method and stream entries in `wifi/NmApi.js` from `nm-daemon debug protocol-registry`, and lints every QML source; any drift or static-analysis failure fails the check.
