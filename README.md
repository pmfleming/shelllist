# shelllist

Quickshell experiments and UI components for desktop menus.

Initial goal: build a Hyprland-friendly Wi-Fi/network popup backed by the existing `nm-wifi` NetworkManager D-Bus helper.

## Usage

Run the Wi-Fi popup with Nix:

```sh
nix run
```

Desktop integration target: bind this command to `SUPER+N` as the Wi-Fi chooser, replacing the old rofi Wi-Fi menu.

The current flake intentionally uses a local `nm-wifi` path input, so it is expected to run on this development machine until that dependency is made portable.

## Wi-Fi popup keybindings

- Type to filter visible SSIDs.
- `Enter`: connect to the selected network.
- `Down` / `Up`: move selection.
- `Right`: open options for the selected network.
- `Left` or `Esc` while options are open: close options.
- `Enter` while options are open: run the selected option.
- `F6`: connect to a hidden SSID.
- `F5`: refresh cached networks, saved profiles, and start a background scan.
- `Esc` while options are closed: close the popup.

Password-protected unsaved networks prompt for a password before Shelllist calls `nm-wifi connect-target`. Hidden SSIDs can be connected with `F6`; leave the password prompt blank for open hidden networks.

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

The Wi-Fi UI entry point is `wifi/shell.qml`; reusable list delegates live beside it as local QML components.
