# shelllist

A single-host Quickshell desktop action center.

Shelllist is a Hyprland-focused desktop action center and top bar. Wi-Fi, Bluetooth, clipboard, application, and bar state are backed by `nm-daemon`, `bt-daemon`, `clip-daemon`, `app-daemon`, and `bar-daemon`. Shelllist owns QML, window behavior, and interactions while the Rust backends own system integration and policy.

## Current status

- One resident `shelllist` Quickshell host owns a 51 px per-monitor top bar and the Applications, Wi-Fi, Bluetooth, and Clipboard surfaces.
- Bluetooth remains eager for hidden pairing requests and Wi-Fi remains eager for authoritative bar status. Application and clipboard controllers plus every chooser view load on first use and remain warm.
- Only one surface is visible at a time; `Ctrl+Alt+Left/Right` switches between loaded surfaces through the common host.
- Default mode: a monitor-aware popover controlled through one IPC target, Waybar, or Hyprland global shortcuts.
- Optional mode: an explicit one-shot floating host for development and fallback use.
- Backend: sibling Rust daemon Git inputs while their current API histories are unpublished; repin them to portable GitHub inputs after publication. The default package includes `bar-daemon` plus its D-Bus and systemd user activation descriptors. Home Manager and NixOS modules install both user services declaratively.
- Target platform: `x86_64-linux` with NetworkManager and Quickshell.

## Top bar

The resident popover-mode host creates one `PanelWindow` per Quickshell screen. `bar-daemon` supplies workspace, media, audio, brightness, battery, power-profile, notification, update, and timezone state through `bar-api` v1. The existing Wi-Fi and Bluetooth controllers remain authoritative for their icons and open their Shelllist surfaces directly. Quickshell owns StatusNotifierItem rendering and native DBusMenu display.

The initial layout intentionally matches the previous Waybar order and 51 px geometry: monitor-local workspaces, centered MPRIS, then tray, network, updates, Bluetooth, audio, brightness, battery, power profile, notifications, timezone city, and clock. It responds to each monitor independently: progressively narrower layouts reduce padding, shorten labels, hide lower-priority status modules, and elide or finally hide media before the left and right clusters can collide. The QML frontend contains no compositor, PipeWire, UPower, SwayNC, or update-state parsing.

The visual bar remains the exclusive-zone owner: each screen gets one fixed-height top-layer `PanelWindow` with `ExclusionMode.Normal`. A debounced surface host reconstructs those windows after output topology changes and detects suspend/resume from a delayed event-loop heartbeat. Recovery is cooldown-limited so DPMS or monitor flapping cannot create a rebuild storm.

Shelllist also replaces a standalone OSD service. Hyprland media-key global shortcuts call `bar-daemon` for output volume/mute, microphone mute, and brightness changes; a non-interactive transient overlay appears on the focused monitor with the resulting state.

## Usage

`nix run` toggles Applications in the resident host. Pass Shelllist arguments after `--`:

```sh
nix run
nix run .# -- open wifi
```

The current development lock uses portable relative references to sibling daemon checkouts because the required histories are not all published yet. Keep Shelllist and the daemon repositories in the same parent directory. Explicit overrides remain available when testing other checkouts.

Once the package is on `PATH`, all surfaces use the single `shelllist` command:

```sh
shelllist                         # toggle Applications
shelllist applications open
shelllist wifi toggle
shelllist bluetooth open
shelllist clipboard open
shelllist hide
shelllist quit                    # stop the resident host
shelllist status                  # JSON host state
shelllist list                    # JSON surface descriptors
shelllist daemon                  # ensure the resident host is running
shelllist run                     # foreground host for systemd/supervision
shelllist floating wifi           # one-shot floating host
```

For declarative startup, import either exported module. Both install the bundled package and supervise Shelllist plus `bar-daemon` under the graphical user session:

```nix
# Home Manager
imports = [ inputs.shelllist.homeManagerModules.default ];
programs.shelllist.enable = true;

# Or in NixOS configuration
imports = [ inputs.shelllist.nixosModules.default ];
programs.shelllist.enable = true;
```

Set `programs.shelllist.systemd.target` for a compositor-specific session target, `systemd.startBarDaemon = false` to rely only on D-Bus activation, or `systemd.environment` for `SHELLLIST_*` theme overrides.

There are deliberately no per-surface compatibility wrappers. Waybar can call `shelllist toggle wifi`. Hyprland can invoke the registered shortcuts directly:

```ini
bind = SUPER, SPACE, global, shelllist:applications
bind = SUPER, N, global, shelllist:wifi
bind = SUPER, B, global, shelllist:bluetooth
bind = SUPER, V, global, shelllist:clipboard
bindel = , XF86AudioRaiseVolume, global, shelllist:volume-up
bindel = , XF86AudioLowerVolume, global, shelllist:volume-down
bindl = , XF86AudioMute, global, shelllist:volume-mute
bindl = , XF86AudioMicMute, global, shelllist:microphone-mute
bindel = , XF86MonBrightnessUp, global, shelllist:brightness-up
bindel = , XF86MonBrightnessDown, global, shelllist:brightness-down
```

The application surface lists standards-visible desktop applications, groups live Hyprland windows, focuses the most-recent running instance with `Enter`, launches non-running applications, and exposes instances plus desktop-defined actions with `Right`. Running rows use single- or multiple-window icons. The details pane separates running instances and desktop-defined actions under **Application** from live usage and compact 30-minute CPU, proportional memory, GPU, disk-I/O, permanent-storage, temporary-storage, and estimated-power graphs under **Resources**. Its header action focuses the first running instance (or launches on the current workspace), **New tile** launches another instance, and each instance has an icon-only focus control with a tooltip. `Shift+Enter` also launches a new tile.

In the Bluetooth device list, `Right` opens details and `Left` closes them. `Ctrl+Tab` cycles Device, Information, and Bluetooth settings tabs, matching the other Shelllist surfaces.

Configure clipboard capture without opening the UI:

```sh
shelllist clipboard pause
shelllist clipboard private
shelllist clipboard resume
shelllist clipboard kept 750
```

The clipboard UI keeps destructive history clearing behind its icon-only header action and confirmation dialog; pause, private-mode, and retention controls are CLI-only. Plain-text entries can be edited directly in their detail card with automatic saving; pasting first commits any pending inline edit. Terminal lifecycle events are deduplicated against method responses, and lag notifications clear uncertain operation state before refreshing history and capture settings.

## Bluetooth implementation status

The Bluetooth surface provides a keyboard-first device list with a search-field scope control for **My Devices** and **all devices**, filtering, global rfkill-aware power plus per-adapter power, bounded discovery with request IDs and cancellation, recoverable operation state, live and optionally cached signal strength, standard battery display, and contextual pair/connect/disconnect behavior. The all-devices scope scans for nearby devices and includes blocked devices, which use a dedicated Bluetooth-off list icon. It shows the cached list immediately, dims last-known signal after discovery ends, and can retain recently found devices long enough to pair. `Right` opens a structured details surface with Device, Information, and Bluetooth settings tabs. The Device tab keeps direct output-device controls together: semantic artwork, component-battery rings, read-only noise-control status, audio profile selection, rename, trust, wake, multipoint, block, and confirmed forget. The Information tab contains read-only device, audio, technical, and service state. Bluetooth settings separate adapter selection and power, visibility and pairing, management behavior, list policy, and adapter information into focused cards. The daemon's persisted device icon and last observed battery state remain visible while a known device is disconnected, including after reboots. The UI communicates only through `bt-api` v1 and opaque device keys; it does not parse `bluetoothctl` output or route actions on MAC addresses. A `shelllist:bluetooth` Hyprland global shortcut is registered alongside the transition IPC command.

Shelllist consumes live Bluetooth, scan, operation, audio, and pairing subscriptions instead of polling. On reconnect or a lagged stream it uses `bluetooth.requests.snapshot` to restore active operations, discovery, and pairing state before refreshing the device snapshot. Reported Fast Pair Hearable Controls state is presented as read-only status: the active mode remains colored while inactive modes are muted. Shelllist does not issue noise-control changes without an authenticated Fast Pair account key. Its application-specific daemon pairing agent handles PIN/passkey input and display, numeric confirmation, authorization, cancellation, and timeout prompts without taking default-agent ownership away from Blueman. Device actions use opaque operation request IDs and live lifecycle events. Operations and failures are tracked per device, so unrelated rows remain usable and expose their own busy, retry, and cancellation state. Pairing prompts reopen the resident surface and retain focus ownership until answered or timed out instead of being rejected when the chooser loses focus. Device IDs come from the daemon's private persistent registry and remain stable for BlueZ-resolved identities; unknown unpaired devices with rotating private addresses remain intentionally uncorrelated. The Device tab reads and switches available A2DP/HSP/HFP codec profiles through the daemon's sanitized native PipeWire API. Live audio subscriptions report sink/source readiness, runtime state, and default-route status without frontend polling. Shelllist does not expose the daemon's optional OBEX file-transfer API.

## Wi-Fi features

Shelllist currently supports:

- typed cached-network snapshot freshness metadata with Shelllist-owned cache refresh while the Wi-Fi UI is visible;
- Wi-Fi software/hardware radio state and adapter availability, with dormant WWAN backend support reserved for a future mobile-broadband surface;
- active status, IP/connectivity detail display, selected-network details, and distinct icons for captive-portal, open, enhanced-open, legacy, personal, enterprise, and unknown security types;
- connection to saved, open, password-protected, hidden, WEP, and enterprise networks through named credential forms driven by daemon-required/optional fields;
- asynchronous `wifi.connect` progress/completion events by `request_id`;
- NetworkManager SecretAgent prompts through `wifi.secret` events;
- optional keyring saving with persistence feedback and explicit prompt cancellation;
- disconnecting Wi-Fi;
- saved-profile actions: disconnect-and-forget, toggle autoconnect, toggle randomized MAC, and toggle hostname sending;
- an advanced saved-profile editor for active-profile Wi-Fi band selection, metered/hidden state, MAC policy, hostname privacy, WPA Personal passwords, IPv4/IPv6 assignment, DNS, DHCP lease metadata, and technical details, with directional animation across all three detail tabs;
- rendered Wi-Fi QR sharing, payload copying, and QRCA scanner launch for open networks or saved profiles whose secret can be read;
- captive-portal helper launch when requested by the UI or suggested by the backend.

Shelllist is the sole owner of automatic captive-portal presentation. It opens one plain-HTTP page only after a successful `wifi.connect` result reports captive-portal connectivity. An active Wi-Fi link is labelled **Sign in required**, **Limited connectivity**, or **No internet access** until NetworkManager reports full connectivity; **Connected** is reserved for full internet readiness. The helper uses a runtime-only Chrome profile, deduplicates automatic opens by network identity plus connect request, and places or focuses its uniquely-classed app window on the workspace where Shelllist initiated the connection. `shelllist-captive-portal --manual --fallback` rotates through additional plain-HTTP probes for manual troubleshooting. Helper journal records include `helper_elapsed_ms` and the first observed window title, allowing browser startup/window-placement time to be separated from a later hotspot redirect; inspect them with `journalctl -t shelllist-captive-portal`.

Forget is a confirmed daemon-owned workflow. For an active network the UI presents **Disconnect & forget**; `nm-daemon` cancels a matching connection attempt, disables autoconnect, confirms deactivation, and removes every saved profile with the selected SSID. Forget removes local NetworkManager state only: a captive hotspot may continue recognizing the device until its network-side login session expires. While a connect request is pending, Shelllist exposes **Cancel** rather than leaving the active connection without an escape action.

Shelllist sends user-entered Wi-Fi secrets through stdin-backed JSON requests only; secrets are not placed on command-line arguments.

## Keybindings

Standard chooser navigation:

- `Down` / `Up`: move selection; `J` / `K` do the same while the result list has focus.
- `Enter`: run the selected result's primary action.
- `Right` / `Left`: open and close details.
- `Ctrl+Alt+Right` / `Ctrl+Alt+Left`: switch to the next or previous Shelllist surface.
- `Esc`: close the current modal or nested detail layer, then details, then the chooser.
- `?` or `F1`: show the contextual shortcut guide, including actions available for the selected result.
- `Ctrl+Tab`: cycle tabs when a chooser has tabbed details.

Application launcher keys:

- Type to filter applications, metadata, and window titles.
- `Enter`: focus the most-recent running instance or launch the application.
- `Shift+Enter`: launch a new instance.
- `Down` / `Up`: move selection.
- `Right`: open running instances and desktop actions.
- `Left`: close details.
- `Ctrl+Tab`: switch between Application and Resources details.
- `F5`: refresh desktop applications and running windows.
- `Esc`: close details, then close the launcher.

General Wi-Fi popup keys:

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

The current `WifiProvider.qml`, `BluetoothProvider.qml`, `ClipboardProvider.qml`, and `ApplicationProvider.qml` adapters map their backend protocols onto this model. The application provider consumes `app-api` v1 summaries and routes identifier-only activation, launch, window-focus, and desktop-action requests back to Rust. It keeps the chooser open through accepted/running operation events and closes only after asynchronous completion; its resource graphs request the latest 30-minute window using the cursor-capable history contract. See [`docs/provider-model.md`](docs/provider-model.md) for the schemas, validation rules, query generations, and action dispatch contract.

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
- `wifi.networks` with cached-list parameters and snapshot freshness metadata;
- `wifi.band.status` and transactional `wifi.band.set` for active saved profiles;
- `wifi.scan`, returning a scan `request_id`;
- `wifi.connectTarget` with the daemon-provided opaque network `key`, returning a connect `request_id`;
- `wifi.secret.provide` for SecretAgent responses.
- `wifi.disconnect`;
- `wifi.profile.operation` for profile details, atomic advanced updates, password reveal, delete, privacy, autoconnect, hostname and sharing operations.

Current event streams used by the UI:

- `wifi.scan`
- `wifi.connect`
- `wifi.band`
- `wifi.secret`
- `wifi.status`
- `network.connectivity`

Cache refresh ownership: Shelllist does not rely on an always-on `nm-daemon-cache-refresh.timer`. While the Wi-Fi UI is visible/in use, it calls `wifi.networks` with `{ "cached": true, "refresh_cache": true }` to show the last cached snapshot immediately and warm the next one in the background. Hiding/unfocusing the popover stops Shelllist's UI-owned refresh loop. Explicit refresh uses `wifi.scan` with `cache: true` and filters `wifi.scan` events by `request_id`.

Status and connectivity are continuous subscriptions rather than polling loops. Closing the UI cancels its scan; closing the JSONL session cancels every remaining session-owned request and subscription.

## Theming and window behavior

The popup uses Nix/Home Manager `SHELLLIST_*` environment values as its single configured theme source, with the Qt/system palette as a portable fallback. It no longer maintains a second asynchronous theme state through `hyprctl getoption`. Shared `Shelllist.Ui` tokens also define spacing, margins, control and status heights, typography, icons, disabled opacity, motion, and list density so applications do not establish parallel visual constants.

Clicking the coloured application tile in the Wi-Fi, Bluetooth, Clipboard, or application launcher header captures the visible app surface and publishes the PNG to the Wayland clipboard through `clip-daemon`.

Wi-Fi and Bluetooth derive a bounded `0.82–1.12` density scale from their available height. List/header spacing, search/header controls, status bars, rows, and details content therefore shrink together on short displays and expand together on taller displays. Their shared refresh tile spins and remains unavailable for the full list refresh; status bars report progress as text without duplicating the refresh animation. Modal prompt cards derive their height from wrapped content rather than fixed pixel heights.

Animation behavior:

- Network Details, Security & Privacy, and IP & DNS animate in both directions without exposing off-screen/stale panes while the chooser expands.
- Under Hyprland, animations are enabled unless `SHELLLIST_NO_ANIMATIONS` overrides them.
- Outside Hyprland, Shelllist defaults to no animations.
- Set `SHELLLIST_NO_ANIMATIONS=1` or `SHELLLIST_NO_ANIMATIONS=0` to override while testing.

Supported color/radius environment overrides include `SHELLLIST_BG`, `SHELLLIST_SURFACE`, `SHELLLIST_TEXT`, `SHELLLIST_SUBTEXT`, `SHELLLIST_BORDER`, `SHELLLIST_STRONG_BORDER`, `SHELLLIST_ACCENT`, `SHELLLIST_SELECTED`, `SHELLLIST_SUCCESS`, `SHELLLIST_DANGER`, `SHELLLIST_WARNING`, and `SHELLLIST_RADIUS`.

The shared `PopupWindowHost` gives each application the same floating fallback, focused-monitor geometry, fixed maximum layer surface, centered animated content, IPC lifecycle, focus grab, compositor rules, and per-namespace animation policy. Shelllist-owned prompts and confirmations use the shared themed modal framework. In floating mode, Shelllist performs one Hyprland focus/float/center placement action and otherwise leaves placement to the portable compositor fallback. Quickshell's private GlobalShortcut compatibility import is isolated in the shared `ShelllistGlobalShortcut.qml` adapter.

## Requirements

- A running NetworkManager service.
- A Wi-Fi device managed by NetworkManager.
- User permissions to control NetworkManager connections through D-Bus/polkit.
- A running or D-Bus-activatable `nm-daemon` session service exposing `org.laufan.NmDaemon`.
- Sibling `nm-daemon`, `bt-daemon`, `clip-daemon`, and `app-daemon` checkouts containing the locked API histories, or corresponding inputs supplied through `--override-input`.

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
shellcheck "$out/bin/shelllist"
portal=$(nix build .#captivePortalBrowser --no-link --print-out-paths)
shellcheck "$portal/bin/shelllist-captive-portal"
shelllist-qmllint qml/Shelllist/{Core,Io,Ui}/*.qml qml/Shelllist/Io/process/*.qml shell/*.qml bar/*.qml bluetooth/*.qml clipboard/*.qml launcher/*.qml wifi/*.qml wifi/networkinput/*.qml wifi/process/*.qml
node tests/check-ip-validation.js wifi/networkinput/IpValidation.js
node tests/check-wifi-qr.js wifi/WifiQr.js
node tests/check-application-lifecycle.js launcher/ApplicationLifecycle.js
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
tests/run-qml-tests.sh
qmlqualitylens measure all --config qmlqualitylens.config.json  # optional static quality report
```

The sole UI entry point is `shell/shell.qml`. It owns the shared `BarController` and creates monitor-local `BarWindow` delegates. `SurfaceRegistry.qml` keeps Bluetooth eager for hidden pairing events and Wi-Fi eager for bar status, loads the other controller bundles on first use, and retains each view after it opens. `ShellContent.qml` retains opened views while the common host handles focused-monitor placement, IPC, focus, and switching. Generic provider contracts, validation, single-pass ranking, keyed incremental ListView synchronization, registry dispatch, and result storage live in the shared `Shelllist.Core` module under `qml/Shelllist/Core/`; shared daemon transport (including bounded exponential restart backoff) lives in `Shelllist.Io`, with Process ownership isolated under its `process/` boundary; shared theming, popup/window behavior, surface behavior, controls, detail cards, toggles, text fields, and modal frames live in `Shelllist.Ui`; `WifiProvider.qml` and `BluetoothProvider.qml` are backend adapters. Frontend-only Wi-Fi helpers are separated by responsibility into `WifiPresentation.js`, `WifiFlow.js`, and `NmApiClient.js`; connection, scan, advanced-profile, network-action, share, and captive-portal flows live in dedicated controller Items rather than the main Wi-Fi controller. Bluetooth device details are likewise split into overview, action, metadata, and adapter-setting sections. Reusable IPv4/IPv6 address and prefix controls live in the `wifi/networkinput` QML module. Their validator distinguishes acceptable, intermediate, and invalid editing states so incomplete addresses remain editable without being saved or immediately presented as errors.

The JSON boundaries with all four daemons are pinned under `contracts/`. `nix flake check` compares each checked fixture with its daemon, validates frontend registry declarations, regenerates the used entries in `wifi/NmApi.js` from `nm-daemon debug protocol-registry`, exercises asynchronous application lifecycle mapping, and lints every QML source; any drift or static-analysis failure fails the check.
