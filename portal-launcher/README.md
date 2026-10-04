# Frontend portal launcher

`shelllist-portal-launch --url URL --workspace WORKSPACE --expires-at-ms DEADLINE`

Called by the UI **only after** a successful `network.portalClaim`. This is a
frontend effect adapter, not a service: it opens a Chromium-family browser with
a private session profile and places/focuses its new window. It consumes the
shared `shelllist-hyprland` native IPC adapter, not `hyprctl`, jq or shell parsing.
The empty workspace means the current compositor workspace. Inputs are bounded;
URL and workspace values never become shell code.

One JSON result on stdout reports `outcome`: `opened`, `failed` (no effect), or
`uncertain` (browser spawn occurred, but window/focus could not be confirmed).
Missing output, crashes and interruption must also be treated as uncertain.
`opened` does not mean network authentication succeeded. The UI forwards the
outcome to `network.portalComplete`; neither helper nor frontend retries it.

Each intent submits its URL, including manual fallback with an existing portal
window. No network identity, automatic deduplication, fallback state or episode
files exist here. The private runtime directory, profile and nonblocking helper
lock are UI execution resources only. An expired intent cannot start a browser.
A network change after the daemon claim cannot be atomic with spawning a browser.

Run `cargo test --manifest-path portal-launcher/Cargo.toml`. Live Chromium/Hyprland
acceptance is separate; unit tests do not open a browser or affect focus.
