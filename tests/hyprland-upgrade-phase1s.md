# Hyprland upgrade: Phase 1S handoff

Prepared 2026-11-05 on the local `hyprland-ipc-gaps` branches under
`/home/laufan/Projects/hyprland-ipc-gaps/`. Nothing has been pushed, merged,
activated or rebooted. **Stop here under D8 of the implementation plan.**

## Prepared changes

Shelllist uses Quickshell v0.3.2 (`4f508be500dea6e5732cc3d50382a0048b17e7b1`)
from its own flake for the application wrapper, gallery, QML lint, native journey,
development shell and development lint wrapper. Its nixpkgs follows Shelllist's
approved `8eeec934ae0dbeca3d7868c059568a65c08b2fc3`. Qt stays at **6.11.1**,
including qtsvg and qmllint. The input policy checks version, revision and shared
nixpkgs identity. The lock adds only this remote input and no local-project pins.

The NixOS branch changes only the `nixpkgs-display` lock node and the Hyprland
floor in `config/scripts/tests/sleep-recovery.py`. The node remains automatic;
`manualInputs` is unchanged. Lock node changed:
`6774f7bc253789b113a4f39285dc0fa100abeacc` →
`1d060086d60cb76a40cf37109f979d88a5bd6396`.

| Component | Before | Prepared |
| --- | --- | --- |
| Hyprland | 0.56.2 | 0.57.1 |
| Quickshell | 0.3.0 | 0.3.2 |
| Kernel | 6.18.53 | 6.18.60 |
| Mesa (both architectures) | 26.2.3 | 26.2.6 |
| Aquamarine | 0.15.1 | 0.16.0 |
| Hyprland portal | 1.4.1 | 1.5.0 |

Phase 0 and Phase 1 commits already present on these branches:

| Repository | Phase 0 | Phase 1 |
| --- | --- | --- |
| daemon-framework | ad2547a | 27927b7 |
| app-daemon | unchanged | ad1d0ce |
| bar-daemon | unchanged | 2732ed1 |
| shelllist | 46577e9 | afe74d6 |
| update-daemon | unchanged | unchanged (7c4b393) |

Phase 1S changes are in this Shelllist commit, the NixOS display-stack commit,
and the framework's Phase 1S evidence/changelog commit. All use the same branch
name. The final implementation response lists their exact tips.

## Review and validation

- Compared upstream v0.3.0 and v0.3.2 source (93 changed source files), with
  focused review of Hyprland workspace/monitor identity, focused workspace,
  IPC handler/CLI changes, process lifecycle, popup anchoring and Wayland
  toplevel/window changes used by Shelllist. Workspace lookup/events now use
  addresses, with non-numbered IDs represented as -1. The later upstream
  workspace-renumbering follow-up is not in v0.3.2 and was not added here.
- Quickshell builds from its own flake against the approved nixpkgs/Qt. Build:
  `/nix/store/32rvs0v76yqgfx10lqdp6ad8ajw1cyqc-quickshell-wrapped-0.3.2`.
- `checks.x86_64-linux.qmlLint`: **passed, max warnings 0**, using this Quickshell.
  Nix/Qt's locale fallback diagnostic is separate from qmllint warnings.
- `checks.x86_64-linux.buildInputs`: **passed**, including the new source/version
  and shared Qt policy. Result:
  `/nix/store/a97x0hmhllysfr8aa5barx5bgayp58kw-shelllist-build-inputs-x86_64-linux`.
- NixOS `checks.x86_64-linux.sleep-recovery`: **passed**, evaluated with the
  prepared display pin. Checks explicit DPMS actions, persistent logging, no
  experimental specialisations, the combined stack and the new Hyprland floor.
- Framework fmt, warning-denied workspace/all-target clippy, and locked workspace
  tests repeated: **80 passed, 2 opt-in tests ignored**.
- App locked full suite repeated: **63 unit and 19 integration tests passed**.
- Bar locked full suite repeated: **325 unit and 33 integration tests passed**.
- Portal launcher locked suite repeated: **4 passed**. Existing opt-in tests stay
  opt-in; bar's native handoff target was separately compiled in Phase 1.
- Nested acceptance passed against both 0.56.2 and the exact queued 0.57.1 build,
  including special-workspace snapshot and work-area reads. See the framework's
  `tests/hyprland-ipc-{baseline,phase1}.md` for setup and captured fixtures.
- Actual installed `hyprland.lua`, including writable monitor/workspace modules,
  passes 0.57.1 `--verify-config` with the correct Lua module search path:
  **config ok**. No user startup hooks were executed.
- Wrapper-provided **0.55.4 hyprctl** successfully executes the
  `HyprlandSettings.js` layer-rule `eval` shape on the private 0.57.1 compositor:
  **ok**. It does not need replacing.
- New `tests/qml/smoke_hyprland_workspace.qml` passed on actual Quickshell 0.3.2
  with a private 0.57.1 compositor, an open special workspace and its focused
  window. Special address is `special:ipc-probe` and its ID is -1, while
  `Hyprland.focusedWorkspace` remains the ordinary active workspace (6).
  `PopupWindowHost.shelllistWorkspaceId()` therefore correctly stays "6" and
  the native popover stays hidden. **No PopupWindowHost change is needed.**
- Full source `shell/shell.qml` hidden-popover smoke passed on the same private
  compositor. Actual CLI `ipc --path ... --newest call shelllist` calls `ping`,
  `status`, `listSurfaces` and `quit` passed; `list --all` retained the config-path
  format used by the wrapper. Status was visible=false, opened={}.
- Both existing `tests/run-runtime-smoke.sh` native UI probes passed with 0.3.2.
  Smoke tests used private homes/data/state directories and a private D-Bus
  configuration without service activation. Expected missing-portal/backend
  warnings remain; there were no TypeError, ReferenceError, binding loops or
  configuration-load failures. v0.3.2 also logs a benign "Signal detected" line
  for the existing IpcHandler property's notification signal.
- The repository's legacy `nixpkgs-fmt` disagrees with pre-existing Nix formatting
  (confirmed on the Phase 1 HEAD). No whole-file formatting churn was included.
  Nix evaluation/build checks pass and `git diff --check` is clean.

The Nix commands used `--no-write-lock-file` and explicit absolute overrides for
unchanged bt/nm/clip repositories; their sibling symlinks are outside the worktree
and Nix pure evaluation otherwise rejects them. System checks likewise selected
the prepared framework/app/bar/Shelllist sources explicitly. No persistent local
pins were created.

## Uncommitted local checkout work

At the final source audit, the five implementation main checkouts and `/etc/nixos`
were clean. Other local inputs have unrelated uncommitted work, left untouched.
`rebuild` would ship these **tracked edits** unless they are finished or set aside:

`/home/laufan/Projects/clip-daemon/`:

- `README.md`
- `src/fake.rs`
- `src/history_store/README.md`
- `src/history_store/database.rs`
- `tests/api.rs`
- `tests/turso_storage.rs`

`/home/laufan/Projects/scratchpad/` (snapshot 2026-11-05T12:17:36+00:00):

- `src/app/app_state/workspace/lifecycle.rs`
- `src/app/services/session_manager.rs`
- `src/app/services/session_store/database/app_safety_tests.rs`

Scratchpad also has untracked `HISTORY-TIMELINE-REVIEW.md`, which is outside the
tracked-source snapshot. nm-daemon, bt-daemon and ts-react-quality-lens are clean.
The Scratchpad file list changed during this audit because that checkout is under
active development. Re-audit before deployment.

## Required next steps and remaining uncertainty

1. User approves merging the prepared local branches. Resolve the unrelated dirty
   input work above before deploying; it is not part of this change.
2. Merge into the main local checkouts, then run `local-build check /etc/nixos`.
   This full coordinated gate is deliberately **not yet run**, per D8's sequence.
3. The user runs **`rebuild`**, then reboots. Do not use `nixos-rebuild` directly.
4. Confirm 0.57.1 and `configProvider=lua`; exercise the bar, app list, numbered
   and special workspaces, portal launcher, popups, docking/undocking, sleep and
   hibernation. Capture real upgraded-session fixtures and confirm the result.
5. Restart both held delayed update timers after the rebuild is confirmed working.
   Phase 2 starts only after that confirmation. `rollback` restores the paired
   compositor/daemon generation; kernel/Mesa problems may require rebooting it.

Actual deployed desktop/hardware recovery remains unverified. A real application
with a non-UTF-8 title is still unverified; Unix-socket replacement decoding is
covered directly. Nested tests use the running compositor as Wayland parent
because current Weston/Sway hosts fail Aquamarine's required protocol versions;
all mutation IPC and applications belong to private child compositor instances.

Both delayed update timers remain inactive. Last worker status:
**staged=false, queued=true, ready=false**. The temporary hold does not survive
reboot; if rebooting before deployment, reapply it and check staging first.
