# shelllist

Quickshell experiments and UI components for desktop menus.

Current focus: a Hyprland-friendly Wi-Fi/network popup backed by the local `nm-api` NetworkManager JSON/JSONL adapter. Shelllist owns the interface; `nm-api` owns NetworkManager behavior.

The popup follows the Qt/system palette for light/dark colors. Under Hyprland it also adopts the compositor's active/inactive border colors, rounding, and global animation setting from `hyprctl getoption`, so Hyprland remains the first-class theming target.

## Usage

Run the Wi-Fi popup with Nix:

```sh
nix run
```

Desktop integration target: bind this command to `SUPER+N` as the Wi-Fi chooser.

By default this keeps the original one-shot floating-window behavior. For a
Waybar-friendly popover, run/toggle the persistent Quickshell daemon instead:

```sh
SHELLLIST_WIFI_MODE=popover nix run
# or explicitly:
nix run .# -- toggle
```

Waybar can use `shelllist-wifi toggle` for `on-click` once the package is on
`PATH`. Popover mode keeps a small Quickshell daemon alive and toggles a real
Quickshell `PanelWindow` over IPC, anchored near the top-right of the screen.

Shelllist currently defaults to its no-animations path. It still detects
Hyprland's global `animations:enabled = false` setting and a floating-window
`no_anim` rule for `Shelllist Wi-Fi`; set `SHELLLIST_NO_ANIMATIONS=0` to force
Shelllist's animated path while testing.

The current flake intentionally uses a local `nm-api` path input, so it is expected to run on this development machine until that dependency is made portable. Shelllist sends Wi-Fi secrets through `--password-stdin` only.

## Wi-Fi popup keybindings

- Type to filter visible SSIDs.
- `Enter`: run the primary action for the selected network.
- `Down` / `Up`: move selection.
- `Right`: open the details pane.
- `Left`: close the details pane.
- `F6`: connect to a hidden SSID.
- `F5`: refresh cached networks, active status, saved profiles, and start a background scan.
- `Esc`: close the popup, or cancel an open prompt.

The popup consumes `nm-api` protocol v1 envelopes:

```json
{ "protocol": "nm-api", "version": 1, "ok": true, "data": {} }
```

## Requirements

- A running NetworkManager service.
- A Wi-Fi device managed by NetworkManager.
- User permissions to control NetworkManager connections through D-Bus/polkit.
- The local `nm-api` helper input at the path configured in `flake.nix`.

## Visible-network connection probe

Shelllist exposes the `nm-api` parity probe so the UI repo and backend repo use the same destructive connection test. By default it is a dry run that inventories visible networks only:

```sh
nix run .#connectParityProbe
```

To actually attempt every selected visible network, pass `--execute` explicitly:

```sh
nix run .#connectParityProbe -- --execute --order alternate --skip-needs-secret
```

The executed probe disconnects between attempts and writes logs under `$XDG_STATE_HOME/nm-api/connect-parity/<timestamp>`.

## Development

```sh
nix develop
```

Useful checks:

```sh
nix flake check --no-build --show-trace
out=$(nix build .#default --no-link --print-out-paths)
shellcheck "$out/bin/shelllist-wifi"
portal=$(nix build .#captivePortalBrowser --no-link --print-out-paths)
shellcheck "$portal/bin/shelllist-captive-portal"
```

The Wi-Fi UI entry point is `wifi/shell.qml`.

The JSON boundary with `nm-api` is pinned by `contracts/nm-api-ui-contract.fixture.json`. `nix flake check` regenerates the fixture with the local `nm-api debug contract-fixture` command and diffs it.
