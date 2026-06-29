# shelllist

Quickshell experiments and UI components for desktop menus.

Current focus: a Hyprland-friendly Wi-Fi/network popup backed by the local `nm-api` NetworkManager JSON/JSONL adapter. Shelllist owns the interface; `nm-api` owns NetworkManager behavior.

## Usage

Run the Wi-Fi popup with Nix:

```sh
nix run
```

Desktop integration target: bind this command to `SUPER+N` as the Wi-Fi chooser.

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
