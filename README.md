# Shelllist

Shelllist is a Hyprland-oriented desktop action center and top bar built with Quickshell. One resident process owns the per-monitor bar and twelve surfaces: **Applications**, **Wi-Fi**, **Bluetooth**, **Clipboard**, **Activity**, **Notifications**, **Time & Weather**, **Displays**, **Battery**, **Audio**, **Media**, and **Tray**.

Rust daemons own system integration, durable state and policy. Shelllist owns windows, layout, keyboard navigation, animation and presentation. A shared popover keeps lists anchored while details expand right; small work areas use explicit scrolling rather than clipping controls. A one-shot floating host is available for development. See [chooser geometry](docs/chooser-geometry.md).

## Top bar

The adaptive 51 px bar contains **Workspaces, Media, Network, Bluetooth, Battery, Notifications, Tray, Clock/date**. It uses one continuous rounded surface, without floating pods or hover tooltips. Narrow bars compact groups and expose horizontal overflow without shrinking fonts or removing keyboard routes. Battery and notification indicators are pictorial; accessible metadata and choosers retain detailed values.

Media shows artwork and transport controls. Music uses Previous/Next; other content uses symmetric ±30-second seeking. Media details can override that mode. The daemon follows recently started playback unless pinned; pins and per-player overrides expire when the player exits. Opening or restoring a result never changes playback policy.

Artwork opens Media; network opens Wi-Fi, with right-click portal fallback; Bluetooth/Battery open their choosers; the bell opens Notifications, with right-click Activity and middle-click DND; Tray opens its list; clock/date open Time & Weather. Update logs use `shelllist:update-logs`, default Super+Shift+U in Home Manager.

A shared OSD frame presents volume, microphone, brightness, power profile, lock keys, idle inhibition, keyboard backlight, privacy and device changes. Now-playing state stays in the bar. See [Material bar](docs/material-bar.md) and [OSD policy](docs/bar-osd.md).

## Surfaces

### Applications

Applications groups standards-visible desktop entries with live Hyprland windows. **Shell, Browser, Code, Media, Text** categories map to workspaces 1–5. `Enter` focuses the most-recent instance or launches; `Shift+Enter` launches another instance. Details expose windows, desktop/close actions, resource graphs and the combined category/workspace setting. Launch-only shortcuts do not claim windows or resource usage. Application actions are asynchronous; a frontend recovery timeout handles a lost terminal backend event without treating an unacknowledged action as success.

The bundled Rust search matcher supports substrings, ordered-character/acronym matches, diacritic folding, multiple terms and conservative typo correction. Exact/prefix matches rank ahead of fuzzy results. See [application behavior and ownership](docs/application-launcher.md).

### Wi-Fi

Wi-Fi supports scanning, saved/hidden networks, personal and enterprise credentials, NetworkManager secret prompts, disconnect/forget, autoconnect/privacy settings, IPv4/IPv6/DNS editing and QR sharing. Secrets use stdin-backed JSON requests, never command-line arguments. Native IP editors retain invalid drafts and show errors on save; malformed CIDR/zone suffixes and truncated pastes cannot silently become accepted addresses.

**Security & Privacy → Cast discovery** applies per-network mDNS policy through `nm-daemon`, without reconnecting. It controls systemd-resolved discovery, not applications using their own mDNS sockets. The NixOS module enables resolve-only support, defaults inherited discovery off and permits UDP 5353 replies. Set `programs.shelllist.discovery.openFirewall = false` for custom firewall rules, or `discovery.enable = false` to manage the resolver stack yourself. Home Manager alone does not configure it; changed system defaults require a rebuild and may need one reconnect.

Automatic captive portals open only after `nm-daemon` validates the connection and grants a one-shot launch claim. Rust owns deduplication and fallback selection; the native `shelllist-portal-launch` helper executes browser/workspace focus. **Sign in** (`Alt+I`) and the bar fallback use that same transaction. Unknown outcomes require explicit retry, never automatic replay. See [portal ownership](docs/reviews/captive-portal-migration.md).

### Bluetooth

Bluetooth supports adapter power/discovery, pairing prompts, connect/disconnect, trust, wake, multipoint, block/forget, battery state, audio profiles and read-only reported noise control. The icon beside search opens **Bluetooth settings** and **List options**, including with an empty list. Device details contain **Device** and **Information**; the icon inside search switches My Devices/All Devices.

Name and setting drafts become saved only after acknowledgement. Failed drafts survive tab changes with Retry/Discard. The UI uses opaque daemon keys and subscriptions, not `bluetoothctl`, MAC-address routing or unauthenticated Fast Pair writes.

### Activity, Notifications, Time & Weather

**Activity** contains a month calendar, agenda, persistent todos and source health. Notifications and weather are independent surfaces, not Activity sections.

**Notifications** provides daemon-backed search, DND, actions, inline replies, 15-minute snooze and dismissal with retained history. Search includes unloaded pages within the newest 5,000 persisted notifications plus live records. Reply drafts survive navigation and clear only after success. `bar-daemon` owns ingestion, expiry, snooze and persistence. See [Activity and notifications](docs/activity.md).

**Time & Weather** lists configured cities with conditions, temperatures, rain chance and local time. Expanded Time details show the selected UTC-offset regions, location, daylight and moon phase; Weather shows hourly and seven-day forecasts.

### Clipboard

Clipboard supports text/image/binary history, copy/paste, inline text editing, favorites, deletion and confirmed history clearing. Reconnection reloads session/settings/history without replaying mutations. Failed saves retain in-memory drafts with Retry/Discard; retry obtains a lease for the original revision rather than overwriting newer content. Drafts are not persisted.

Capture controls are also available through `shelllist clipboard pause`, `private`, `resume`, and `kept COUNT` (for example, `shelllist clipboard kept 750`).

### Displays

Displays lists connected outputs, including disabled screens. Expanded details show a layout map above **Settings/Information**. Settings includes mirror/extend, mode, scale and rotation/reflection; the search gear opens global focus settings. Arrange independent displays by edge-dragging or **Alt+L/U/D/R** for Left/Above/Below/Right. With three or more eligible displays, a reference dropdown selects the target; selecting it alone never moves a screen. There are no separate X/Y position fields or Arrange subpage.

Changes remain local until **Preview changes** (`Ctrl+Enter`) previews the whole layout. **Keep** saves; Escape, closure or the daemon's 20-second deadline reverts. Navigation preserves drafts; topology changes invalidate stale layouts. Identify does not enable or focus a screen. Narrow outputs retain the split layout with scrolling, not a replacement Back page.

The laptop's **When docked** preference saves independently after acknowledgement and restores the laptop display when external screens disconnect. See [Displays](docs/displays.md) for recovery, focus policy and arrangement constraints.

### Battery & Power

Three tabs separate controls:

- **Power:** power mode, live status, charge/energy history and estimated per-application energy since the last charge or across the last week.
- **Battery:** device selection, firmware thresholds, one-time full charging, pause/resume, calibration, notifications, health and hardware details.
- **Suspend:** battery-level rules, adaptive hardware tuning, lock/suspend/hibernate, inhibitors, lid policy and inactivity profiles.

History combines charge percentage and measured battery watts over 6h/24h/7d observed-time ranges. Offline periods are omitted; missing observations break lines. Forecasts target empty or full/the protection limit and remain unplotted when implausible. Plot inspection is pointer-entry-only, outside field Tab traversal. These are battery-flow measurements, not AC wall power; application attribution is `app-daemon`'s low-confidence RAPL CPU-time estimate, excluding system-only loads such as displays and radios.

Low/Critical rules combine threshold notifications and supported automatic power profiles while unplugged, with a three-point recovery margin. Manual profile selection pauses automatic switching until recovery or AC; Resume is explicit. Notifications do not require a power-profile service.

Lock/Suspend/Hibernate commands are immediate and capability-guarded; suspend/hibernate require confirmed screen locking. Blockers and failures show status, with explicit Retry rather than automatic replay. Managed lid actions require the active local graphical session and ignore docked/external-display use; stopping the daemon restores logind policy.

Automatic profiles set inactivity before suspend and additional suspended time before hibernation, shared or separate for battery/AC. Either delay supports **Never**. The initial shared profile is 30 minutes to suspend, Never hibernate. Changing inactivity delay restarts its countdown; hibernate delay is selected at suspend entry, not changed by later AC events. Settings persist in `$XDG_CONFIG_HOME/bar-daemon/sleep.json`.

Home Manager enables `programs.shelllist.suspend.enable` when it manages hypridle and bar-daemon. Managed hypridle uses native `Type=notify` readiness; an old `Type=simple` service is unavailable, not treated as acknowledged. Existing lock/DPMS settings remain, but includes/custom suspend commands need manual migration; disable the option to retain an independent idle policy. The old `programs.shelllist.sleep.enable` option remains an alias, without changing daemon API or persisted names.

Timed hibernation requires working swap/resume, logind capability, confirmed locking and the updated privileged `bar-battery-helper`. Rebuild both system and Home Manager integration. Firmware writes use system D-Bus and polkit; Shelllist stays unprivileged. Home Manager alone can display telemetry but cannot install those system artifacts. See [bar-daemon power/suspend documentation](https://github.com/pmfleming/bar-daemon/blob/main/docs/power-sleep.md).

### Audio, Media and Tray

Audio provides default output/input state, acknowledged mute, 5% output-volume commands and the full mixer. Media lists players with capability-guarded actions targeting the inspected player. Tray offers activation, native menus, secondary activation and scrolling; ambiguous IDs cannot dispatch effects. Restoring these surfaces never opens menus or replays actions.

Home Manager provides configurable Super+Shift+A/M/T bindings; set `audioShortcut`, `mediaShortcut` or `trayShortcut` to null to disable one.

## Architecture

| Area | Owner |
| --- | --- |
| Applications and process resources | `app-daemon` / `app-api` v1 |
| NetworkManager and Wi-Fi policy | `nm-daemon` / `nm-api` v1 |
| Bluetooth, pairing and profiles | `bt-daemon` / `bt-api` v1 |
| Clipboard capture/history | `clip-daemon` / `clip-api` v1 |
| Bar, power, displays, Activity, notifications, media and hardware state/effects | `bar-daemon` / `bar-api` v1 |
| Rendering, navigation, monitor routing, tray menus and transient OSD | Shelllist / Quickshell |

`shell/shell.qml` is the only UI entry point. Wi-Fi/Bluetooth load eagerly for the bar and pairing prompts; Applications/Clipboard load on demand. Opened surfaces remain warm. Shared JSONL transport provides bounded restart backoff; checked fixtures in `contracts/` guard protocol compatibility. See the [daemon boundary audit](docs/daemon-boundary-audit.md), [provider model](docs/provider-model.md) and [documentation index](docs/README.md).

Compositor and work-area projections share `BarProjectionBackend`; individual controllers retain validation, revision fencing and unavailable-state behavior. Transport recovery refreshes observations without authorizing duplicate effects or committing field drafts.

## Installation

Requirements: Linux `x86_64` through the current flake, Hyprland, Quickshell, NetworkManager, BlueZ, PipeWire/WirePlumber, the five domain daemons and appropriate D-Bus/polkit/service permissions.

Keep `shelllist`, `daemon-framework` and all five daemons under one parent directory. Hyprland IPC lives in `daemon-framework/crates/shelllist-hyprland`; no separate checkout is needed. From this repository, run against current worktrees:

```sh
../daemon-framework/tools/local-build run . -- open wifi
```

The checkout launcher requires Cargo/Rust, Git and Nix; the packaged native `local-build` requires neither Cargo nor Python. It snapshots tracked edits, rejects untracked files and resolves only a disposable lock. Ordinary `nix run/build/flake check` can recreate local deployment pins; use `local-build` instead.

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

Both modules install Shelllist and can supervise the resident host and `bar-daemon`. The bundled daemon owns `org.freedesktop.Notifications` and conflicts with `swaync.service`; disable other notification daemons. Configure `programs.shelllist.systemd.target` for a compositor-specific session target, `systemd.startBarDaemon = false` for D-Bus activation, or `systemd.environment` for theme overrides. Other domain daemons need their own running services or D-Bus activation.

NixOS additionally installs privileged battery integration and read-only Intel RAPL access. Set `programs.shelllist.resources.enableRaplAccess = false` to disable RAPL access.

## CLI

```text
shelllist                         Toggle Applications
shelllist <surface> [open|toggle] Open or toggle a surface
shelllist open <surface>          Open a surface
shelllist toggle <surface>        Toggle a surface
shelllist floating <surface>      Run a one-shot floating host
shelllist hide                    Hide the popover
shelllist status                  Print host state as JSON
shelllist list                    List surfaces as JSON
shelllist responsiveness          Print interaction timings as JSON
shelllist daemon                  Ensure the resident host is running
shelllist run                     Run the host in the foreground
shelllist quit                    Stop the resident host
```

Surface names: `applications`, `wifi`, `bluetooth`, `clipboard`, `activity`, `notifications`, `time-weather`, `displays`, `battery`, `audio`, `media`, `tray`. Run `shelllist quit` before starting floating mode.

## Keyboard use

| Context / key | Action |
| --- | --- |
| Search Left/Right | Native cursor/selection movement |
| Search Down | Select/focus the first result |
| Results Up/Down | Move selection without changing expansion; first-result Up returns to search |
| Results typing | Return to the query's saved cursor |
| Results Enter | Run the primary action |
| Results Right/Left | Expand/collapse details without transferring focus |
| Ctrl+Tab / Ctrl+Shift+Tab | Change detail pages |
| Ctrl+Alt+Left/Right | Switch surface |
| F5 | Refresh where supported |
| Escape | Leave the current editor, modal, details or popover |

Tab enters expanded details; Tab/Shift+Tab wrap through **editable controls only**. Enter starts editing or toggles an on/off switch. While editing, arrows remain native, **Enter saves**, **Escape discards**, and **Tab saves and continues editing the next field**. Arriving at a switch never toggles it. Other exits discard uncommitted field edits; volume/brightness previews roll back on Escape. Save requests are not acknowledgements.

Actions use **Alt+letter**, not field Tab stops. Alt+J opens additional content actions; Alt+M opens header overflow; Alt+Enter invokes search's trailing action; Alt+S captures the view. Required-input dialogs retain conventional contained traversal. There are no F1 overlays or hover tooltips. Read the mandatory [interaction contract](docs/chooser-keyboard-workflow.md) before panel changes.

Wi-Fi retains F6 for hidden-network entry, F7 for security and F8 for IP settings. Holding Alt reveals command badges after a short delay; holding Ctrl reveals detail-tab hints. Neither modifier changes the selected result.

Per-result tab/scroll/field locations survive until process exit without changing expansion or stealing list focus. Applications/Bluetooth also restore ordinary invocation focus, caret/selection and keyed viewport, never menus or sensitive prompts. See [session memory](docs/chooser-session-memory.md).

Example Hyprland bindings:

```ini
bind = SUPER, SPACE, global, shelllist:applications
bind = SUPER, N, global, shelllist:wifi
bind = SUPER, B, global, shelllist:bluetooth
bind = SUPER, V, global, shelllist:clipboard
bind = SUPER, P, global, shelllist:battery
bind = SUPER, T, global, shelllist:time-weather
bindel = , XF86AudioRaiseVolume, global, shelllist:volume-up
bindel = , XF86AudioLowerVolume, global, shelllist:volume-down
bindl = , XF86AudioMute, global, shelllist:volume-mute
bindl = , XF86AudioMicMute, global, shelllist:microphone-mute
bindel = , XF86MonBrightnessUp, global, shelllist:brightness-up
bindel = , XF86MonBrightnessDown, global, shelllist:brightness-down
```

## Theme and motion

The desktop accent seeds Google's Material Tonal Spot palette; light/dark follows Qt's desktop preference with a window-palette fallback. Controls are opaque, the chooser shell uses 94% opacity, and forms use filled native editors with passive labels/supporting rows. Browsing highlights only the editable control with a tonal fill and contrast-qualified marker; editing adds a stronger accent edge. Typography uses packaged Roboto Flex, Material Symbols Rounded and a Nerd Font fallback. Icon-only controls retain accessible names.

```text
SHELLLIST_ACCENT         # Palette seed, not an exact primary-role color
SHELLLIST_FONT           # Typography override
SHELLLIST_ICON_FONT      # Specialist icon fallback
SHELLLIST_RADIUS         # Remaining legacy controls
SHELLLIST_BLUR           # false disables Lua Hyprland blur
SHELLLIST_NO_ANIMATIONS  # 1 disables motion; 0 explicitly enables it
```

Without an override, motion follows Hyprland's preference through `bar-daemon` snapshots/subscriptions and is disabled elsewhere. Old per-role color overrides no longer apply; resource-series overrides remain separate. Live blur, spring tuning, IME and screen-reader acceptance remain distinct from offscreen tests. See [visual foundation](docs/material-visual-foundation.md).

## Development

```sh
../daemon-framework/tools/local-build develop .
tests/check-sibling-boundary.sh
```

The sibling gate snapshots current tracked worktrees once, including dirty files, and runs the full framework/daemon/UI check matrix. All five daemons share one framework source. Git-add new files first (`git add -N` is sufficient); no source commits or manual lock updates are needed. It neither fetches branches nor activates services. Persistent locks retain third-party dependencies only.

The complete gate includes daemon protocol contracts, JavaScript policies, generated-source freshness, QML interaction tests, strict lint, module evaluation, packaged imports, framework workspace tests and all five daemon package suites. Passing offscreen tests does not replace live compositor or hardware acceptance.

Focused checks inside the development environment:

```sh
tests/run-qmllint.sh
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
node tools/build-typescript.mjs --check
tsc --project tsconfig.json
tests/run-qml-tests.sh
tests/run-performance-benchmarks.sh
# Installed resident host hidden:
tests/benchmark-resident.py --duration 20 --check
# Target Wayland session; opens every surface twice:
tests/benchmark-responsiveness.py --check
```

Edit generated presentation logic under `typescript/`, then run `node tools/build-typescript.mjs` and commit the corresponding JavaScript. The manifest maps sources to outputs; freshness checks prevent drift. QML tests run against packaged shared imports and domain fixtures, including bar/display sources.

The policy benchmark writes `target/performance/qmlbench.json`; resident measurements cover hidden CPU, PSS, faults and bridge threads. Responsiveness measurements cover acknowledgement, first frame, cold readiness, search and model latency. See [QML quality guidance](docs/qml-quality-review.md) for maintenance gates and validation limits.

For a standalone build, use `../daemon-framework/tools/local-build build .`. The desktop `rebuild` uses the same current-source policy and one frozen graph for mandatory checks and deployment.
