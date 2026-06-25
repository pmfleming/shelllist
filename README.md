# shelllist

Quickshell experiments and UI components for desktop menus.

Initial goal: build a Hyprland-friendly Wi-Fi/network popup backed by the existing `nm-wifi` NetworkManager D-Bus helper. The Wi-Fi popup is a two-pane network chooser and connection detail dashboard.

## Usage

Run the Wi-Fi popup with Nix:

```sh
nix run
```

Desktop integration target: bind this command to `SUPER+N` as the Wi-Fi chooser, replacing the old rofi Wi-Fi menu.

The current flake intentionally uses a local `nm-wifi` path input, so it is expected to run on this development machine until that dependency is made portable. Shelllist uses `nm-wifi --password-stdin` for safer password prompts.

## Wi-Fi popup keybindings

- Type to filter visible SSIDs.
- `Enter`: connect to the selected network.
- `Down` / `Up`: move selection.
- `F6`: connect to a hidden SSID.
- `F5`: refresh cached networks, active status, saved profiles, and start a background scan.
- `Esc`: close the popup, or cancel an open prompt.

The right pane shows selected-network actions and details. Connected networks expose disconnect, captive-portal sign-in, forget, autoconnect, IPv4, DNS, frequency, link-speed, and MAC details when `nm-wifi status --json` can read them from NetworkManager. Password-protected unsaved networks prompt for a password before Shelllist calls `nm-wifi connect-target`; Shelllist sends the password over stdin to avoid exposing it in process arguments. Hidden SSIDs can be connected with `F6`; leave the password prompt blank for open hidden networks.

## Requirements

- A running NetworkManager service.
- A Wi-Fi device managed by NetworkManager.
- User permissions to control NetworkManager connections through the system D-Bus policy/polkit setup.
  - On many desktop NixOS systems this works for active local sessions through polkit.
  - If profile changes or connections fail with permission errors, check NetworkManager/polkit permissions for the user/session.
- The local `nm-wifi` helper input must be present at the path configured in `flake.nix`.

## Development

Enter the development shell:

```sh
nix develop
```

Included tools:

- `quickshell`
- `shellcheck`
- `nixpkgs-fmt`
- `qmlformat` from Qt declarative tools

Useful checks:

```sh
nix flake check --no-build --show-trace
out=$(nix build .#default --no-link --print-out-paths)
shellcheck "$out/bin/shelllist-wifi"
portal=$(nix build .#captivePortalBrowser --no-link --print-out-paths)
shellcheck "$portal/bin/shelllist-captive-portal"
```

The Wi-Fi UI entry point is `wifi/shell.qml`.
