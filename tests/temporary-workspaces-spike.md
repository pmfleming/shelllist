# Temporary workspace stage 1 evidence

2026-11-02. Stage 1 establishes Rust wire types and exact-session compositor
primitives. Product lifecycle, launch routing and QML controls remain subsequent
stages. The source tree inspected for API shape is not the installed build;
acceptance below uses installed Hyprland 0.56.2, commit
`efb50993780079460b0cbed1363e2166a2de1d9f`.

## Executed checks

- Rust core and Hyprland crates: 25 unit/binary tests passed.
- Opt-in `private_workspace` integration: one passed. An isolated nested Hyprland
  with an empty configuration maps a Weston flower client, moves it from 6 to 7,
  rejects close for stale membership on 6, and observes normal close on 7.
  The captured weak window reference is consumed; a second close is rejected.
- The same test creates a second headless output. Focus into a workspace owned
  by the other monitor is rejected. Background local replacement succeeds while
  retaining the original keyboard-focused monitor.
- Formatting and strict Clippy cover both changed crates and all their targets.

Commands run from the pinned framework Nix development environment:

```text
cargo test --manifest-path /home/laufan/Projects/daemon-framework/Cargo.toml --locked -p shelllist-daemon-core -p shelllist-hyprland -- --include-ignored --nocapture
cargo clippy --manifest-path /home/laufan/Projects/daemon-framework/Cargo.toml --locked -p shelllist-daemon-core -p shelllist-hyprland --all-targets -- -D warnings
cargo fmt --manifest-path /home/laufan/Projects/daemon-framework/Cargo.toml --all
```

The opt-in test needs `WORKSPACE_TEST_WESTON` (Weston package root),
`WORKSPACE_TEST_HYPRLAND` (installed executable), and a compatible render parent.
For this run `WORKSPACE_TEST_PARENT_DISPLAY` named the existing Wayland socket;
the nested compositor used a separate runtime directory, empty configuration and
unreachable D-Bus address. All mutation IPC targeted the nested signature and
test client. Evidence logs for the passing run: `/tmp/ws-Vl4wGB/`.

Standalone Weston 15 and Sway 1.12 headless parents were also attempted. The
installed Hyprland requested unsupported version 6 globals (wl_compositor from
Weston, xdg_wm_base from Sway); those attempts failed before test effects. The
passing nested run does not claim compatibility with those test parents.

## Contract consequences

Read complete JSON batches with Serde's streaming deserializer. Dispatcher return
tables require `.ok` validation; truthiness is insufficient. Rust encodes atomic
compositor identity guards and validated identifiers. No standalone Lua policy
or frontend allocation logic is introduced.

Bar/app communication uses their existing authenticated same-session service
boundary. Request keys and session generations are required for durable lookup;
app's existing memory-only operation registry is not crash recovery. Transport
restart and writer fencing must pass the later daemon integration tests before
the feature is exposed.

Remaining acceptance belongs to later stages: app save/cancel, late/singleton and
D-Bus handoffs, persistent class rules, real output unplug/replug, crash boundaries,
UI transactions and packaged compatibility. This spike is not rollout evidence.
