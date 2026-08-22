# Shelllist

Shelllist is a Hyprland-oriented desktop action center and top bar built with Quickshell. One resident process owns the per-monitor bar and six keyboard-first surfaces: **Applications**, **Wi-Fi**, **Bluetooth**, **Clipboard**, **Activity**, and **Battery**.

Rust daemons handle system integration and policy. Shelllist handles windows, layout, navigation, animation, and presentation.

## What it provides

- A 51 px adaptive top bar on every monitor.
- One adaptive popover host: chooser surfaces are centered, while Activity uses a right-edge glance panel that expands inward.
- A one-shot floating mode for development and fallback use.
- One shared OSD frame for volume, microphone, brightness, power profile, lock keys, idle inhibition, keyboard backlight, privacy indicators, audio-device changes, and display-output changes. Now-playing state stays in the top bar instead of appearing as an OSD.
- Global shortcuts and one IPC/CLI entry point.
- Shared result, action, details, theme, and daemon-transport components.

### Top bar

The bar contains:

- monitor-local workspaces with themed application icons and an animated active indicator;
- the focused application on the active monitor;
- artwork, title, progress, and previous/play-pause/next controls for the selected MPRIS player;
- StatusNotifierItem tray icons and native DBusMenu menus;
- network, update, Bluetooth, audio, brightness, battery, power-profile, notification, timezone, and clock modules.

Modules collapse progressively on narrow outputs. The bar uses flat controls, translucent status pods, and no hover tooltips.

Common bar interactions:

| Module | Left click | Right click | Wheel |
| --- | --- | --- | --- |
| Workspace | Focus workspace | — | — |
| Focused application | Open Applications | — | — |
| Media | Play/pause or use its three controls | — | — |
| Network | Open Wi-Fi | Open captive-portal fallback | — |
| Bluetooth | Open Bluetooth | — | — |
| Audio | Open `pavucontrol` | Toggle mute | Adjust volume |
| Brightness | Increase | Decrease | Adjust brightness |
| Battery | Open Battery | — | — |
| Activity / clock | Open Activity | — | — |
| Notifications | Open Activity | Toggle DND | — |

`bar-daemon` supplies normalized bar state through `bar-api` v1. Wi-Fi and Bluetooth remain owned by their dedicated Shelllist controllers, while Quickshell owns tray rendering and menus.

## Surfaces

### Applications

The launcher lists standards-visible desktop entries and groups live Hyprland windows with their applications. Apps can be browsed as **Shell**, **Browser**, **Code**, **Media**, or **Text**. Choosing a category in an app's Settings also chooses its default workspace: the five categories map to workspaces 1–5 respectively. `Enter` focuses the most-recent instance or launches the application; `Shift+Enter` launches another instance. Details expose running windows, desktop actions, close actions, interactive 30-minute, two-hour, and 24-hour resource graphs, and the combined category/workspace setting.

Launch-only desktop entries remain shortcuts and do not claim windows or resource usage. Application actions are asynchronous and protected by a frontend recovery timeout if a terminal backend event is lost.

### Wi-Fi

The Wi-Fi surface supports scanning, saved and hidden networks, open/WEP/WPA personal and enterprise credentials, NetworkManager secret prompts, disconnect/forget, autoconnect and privacy settings, IPv4/IPv6 and DNS editing, Wi-Fi QR sharing, and captive-portal launch.

Shelllist opens an automatic captive portal only after a successful connection reports captive connectivity. User-entered secrets travel through stdin-backed JSON requests and are never placed in command-line arguments.

### Bluetooth

The Bluetooth surface supports adapter power, bounded discovery, known and nearby devices, pair/connect/disconnect, pairing-agent prompts, trust/wake/multipoint/block/forget actions, persisted battery state, audio profiles, and read-only reported noise-control state.

The UI uses opaque daemon device keys and live subscriptions. It does not parse `bluetoothctl`, route actions by MAC address, or issue unauthenticated Fast Pair noise-control changes.

### Activity

The Activity surface combines local time and optional Open-Meteo weather, a month calendar, selected-day agenda, persistent todos, native notification history/actions/DND, source health, and world clocks. `bar-daemon` owns notification ingestion, expiry, timed DND, snooze wakeups, grouping metadata, and persistent history. Shelllist renders grouped expandable toast stacks on the originating monitor, with focused-monitor fallback, and paginated grouped history. Notifications support actions, inline replies, 15-minute snooze, per-group/application clearing, and clear-all. See [`docs/activity.md`](docs/activity.md).

### Clipboard

The clipboard surface supports text, image, and binary history; copy and paste actions; inline text editing; favorites; entry deletion; and confirmed history clearing.

Capture policy is also available from the CLI:

```sh
shelllist clipboard pause
shelllist clipboard private
shelllist clipboard resume
shelllist clipboard kept 750
```

### Battery

The Battery surface shows live charge, power state, remaining time, health, cycle count, and per-device details from `bar-daemon`. It includes seven-day charge and time-to-full graphs plus estimated per-application energy ranked since the last charge or across the last week. Application attribution comes from `app-daemon`'s low-confidence RAPL CPU-time estimate; system-only loads such as the display and radios are not assigned to apps. On supported ThinkPads it also manages the native firmware charge-start and charge-stop thresholds, enables or disables threshold protection, and provides a one-time charge-to-100% action. Alert thresholds and full-charge notifications are editable in the same surface. Battery settings apply automatically: toggles are immediate, while slider changes are coalesced and applied after editing finishes without Save or Apply buttons.

Battery settings are written through a privileged system D-Bus helper with polkit authorization; Shelllist itself remains unprivileged. The NixOS module installs and registers the helper automatically. A Home Manager-only installation can display telemetry, but setting ThinkPad firmware thresholds additionally requires installing the `bar-daemon` system D-Bus, systemd, and polkit artifacts at the system level.

## Architecture

| Area | Owner |
| --- | --- |
| Applications and process resources | `app-daemon` / `app-api` v1 |
| Wi-Fi and NetworkManager policy | `nm-daemon` / `nm-api` v1 |
| Bluetooth, pairing, and audio profiles | `bt-daemon` / `bt-api` v1 |
| Clipboard history and capture | `clip-daemon` / `clip-api` v1 |
| Bar state, Battery/ThinkPad policy, Activity/notification data, hardware OSD state, and media-key effects | `bar-daemon` / `bar-api` v1 |
| Windows, rendering, navigation, monitor routing, tray menus, and transient OSD policy | Shelllist / Quickshell |

`shell/shell.qml` is the only UI entry point. Wi-Fi and Bluetooth load eagerly because the bar and hidden pairing requests need them. Applications and Clipboard load on first use. Opened surfaces remain warm.

Every daemon connection uses the shared JSONL transport with bounded restart backoff. Checked fixtures in `contracts/` prevent frontend/backend protocol drift.

See the [`docs/` index](docs/README.md), especially:

- [`docs/provider-model.md`](docs/provider-model.md) for normalized result/action contracts;
- [`docs/list-interaction-contract.md`](docs/list-interaction-contract.md) for mouse, touchpad, and touch list scrolling;
- [`docs/application-launcher.md`](docs/application-launcher.md) for launcher behavior and ownership;
- [`docs/activity.md`](docs/activity.md) for Activity and notification behavior;
- [`docs/bar-osd.md`](docs/bar-osd.md) for OSD sources, presentation, and timeout policy;
- [`docs/qml-quality-review.md`](docs/qml-quality-review.md) for QML structure and validation rules.

## Installation

The flake currently pins sibling daemon checkouts through relative Git inputs. Keep `shelllist`, `app-daemon`, `bar-daemon`, `bt-daemon`, `clip-daemon`, and `nm-daemon` in the same parent directory, or override those inputs.

Run directly:

```sh
nix run
nix run .# -- open wifi
```

Home Manager:

```nix
imports = [ inputs.shelllist.homeManagerModules.default ];
programs.shelllist.enable = true;
```

NixOS:

```nix
imports = [ inputs.shelllist.nixosModules.default ];
programs.shelllist.enable = true;
```

Both modules install Shelllist and can supervise the resident host plus `bar-daemon`. The bundled daemon runs in native notification mode, owns `org.freedesktop.Notifications`, and conflicts with `swaync.service`; disable any separately configured notification daemon. Set `programs.shelllist.systemd.target` for a compositor-specific session target, `systemd.startBarDaemon = false` to use D-Bus activation, or `systemd.environment` for theme overrides. The NixOS module additionally registers the packaged system D-Bus, systemd, and polkit artifacts used by privileged battery settings. The other domain daemons must be running or D-Bus activatable through their own installations.

## CLI

```text
shelllist                         Toggle Applications
shelllist <surface> open          Open a surface
shelllist <surface> toggle        Toggle a surface
shelllist open <surface>          Open a surface
shelllist floating <surface>      Run a one-shot floating host
shelllist hide                    Hide the popover
shelllist status                  Print host state as JSON
shelllist list                    List surfaces as JSON
shelllist daemon                  Ensure the resident host is running
shelllist run                     Run the host in the foreground
shelllist quit                    Stop the resident host
```

Surfaces are `applications`, `wifi`, `bluetooth`, `clipboard`, `activity`, and `battery`.

## Keyboard use

Common chooser keys:

| Key | Action |
| --- | --- |
| Type | Filter visible results |
| `Up` / `Down`, `K` / `J` | Move selection |
| `Enter` | Run the primary action |
| `Right` / `Left` | Open or close details |
| `Ctrl+Tab` | Cycle detail tabs |
| `Ctrl+Alt+Left/Right` | Switch Shelllist surface |
| `F5` | Refresh the current surface |
| `?` or `F1` | Show contextual shortcuts |
| `Esc` | Close the current modal, details, or popover |

Surface-specific additions include `Shift+Enter` for a new application instance; `F6`–`F8` for hidden-network, security, and IP settings; and Clipboard copy/paste/delete combinations. The contextual shortcut dialog is authoritative for the active surface and state.

Suggested Hyprland bindings:

```ini
bind = SUPER, SPACE, global, shelllist:applications
bind = SUPER, N, global, shelllist:wifi
bind = SUPER, B, global, shelllist:bluetooth
bind = SUPER, V, global, shelllist:clipboard
bind = SUPER, P, global, shelllist:battery
bindel = , XF86AudioRaiseVolume, global, shelllist:volume-up
bindel = , XF86AudioLowerVolume, global, shelllist:volume-down
bindl = , XF86AudioMute, global, shelllist:volume-mute
bindl = , XF86AudioMicMute, global, shelllist:microphone-mute
bindel = , XF86MonBrightnessUp, global, shelllist:brightness-up
bindel = , XF86MonBrightnessDown, global, shelllist:brightness-down
```

## Theme and motion

The Qt/system palette is the fallback. Environment variables supplied to the resident process are authoritative:

```text
SHELLLIST_BG             SHELLLIST_SURFACE      SHELLLIST_TEXT
SHELLLIST_SUBTEXT        SHELLLIST_BORDER       SHELLLIST_STRONG_BORDER
SHELLLIST_ACCENT         SHELLLIST_SELECTED     SHELLLIST_SUCCESS
SHELLLIST_DANGER         SHELLLIST_WARNING      SHELLLIST_RADIUS
SHELLLIST_FONT           SHELLLIST_ICON_FONT    SHELLLIST_NO_ANIMATIONS
```

Animations default on under Hyprland and off elsewhere. Set `SHELLLIST_NO_ANIMATIONS=1` or `0` to override that behavior.

## Requirements

- Linux on `x86_64` through the current flake;
- Hyprland for compositor integration and global shortcuts;
- Quickshell;
- NetworkManager for Wi-Fi;
- BlueZ and PipeWire/WirePlumber for Bluetooth audio;
- the five sibling domain daemons described above;
- appropriate D-Bus, polkit, backlight, and service permissions.

## Development

```sh
nix develop
nix flake check
```

Focused checks:

```sh
shelllist-qmllint qml/Shelllist/{Core,Io,Ui}/*.qml shell/*.qml activity/*.qml \
  bar/*.qml battery/*.qml bluetooth/*.qml clipboard/*.qml launcher/*.qml \
  wifi/*.qml wifi/networkinput/*.qml wifi/process/*.qml
node tests/check-bar-presentation.js bar/BarPresentation.js
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
tests/run-qml-tests.sh
```

`nix flake check` also verifies every daemon contract fixture, JavaScript policy test, QML test, module evaluation, and the packaged host.
