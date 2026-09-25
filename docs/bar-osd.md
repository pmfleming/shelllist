# Bar OSD contract

Shelllist uses one shared OSD frame for transient system feedback, instantiated by the bar host on each active output. Every event is normalized to the same presentation descriptor before `bar/BarOsdContent.qml` renders it.

## Descriptor

```js
{
  kind: "brightness",
  icon: "…",
  label: "Brightness",
  valueLabel: "65%",
  percent: 65,
  progressVisible: true,
  timeoutMs: 1400
}
```

`BarController.presentOsd()` applies defaults, clamps `percent` to 0–100, enforces a minimum 400 ms timeout, replaces the current descriptor, and restarts the single dismissal timer. `BarOsdContent.qml` owns only frame layout and animation; type-specific formatting and transition selection live in `bar/BarOsdPresentation.js`.

## Event sources

| OSD | Trigger/source | Progress |
| --- | --- | --- |
| Output volume | Successful volume or mute operation response | Volume percent |
| Microphone | Successful input-mute operation response | Hidden |
| Display brightness | Successful brightness operation response | Brightness percent |
| Brightness error | Failed brightness response/send, or transport loss with a pending adjustment | Hidden |
| Power profile | `power-profile.changed` profile transition | Hidden |
| Caps Lock / Num Lock | `osd-hardware.changed` LED transition | Hidden |
| Keyboard backlight | `osd-hardware.changed` brightness transition | Backlight percent |
| Camera / microphone privacy | `osd-hardware.changed` privacy LED transition | Hidden |
| Idle inhibitor | `power-sleep.changed` idle-inhibition transition | Hidden |
| Audio input/output device | `audio.changed` default node transition | Hidden |
| Display output | `workspaces.changed` monitor addition/removal | Hidden |

Brightness failures display “Adjustment failed” for three seconds without changing the last confirmed brightness. Detailed errors remain in the journal; requests are never automatically retried.

Initial subscription snapshots do not produce an OSD. Domain OSDs require a previous available state so connecting or restarting `bar-daemon` does not replay every current condition as user feedback. Media state remains visible in the top bar and never produces an OSD.

## Responsiveness

- Bind compositor keys directly to `shelllist:*` global shortcuts, not to CLI
  processes. The CLI remains useful for scripts and starting a stopped host.
- The focused monitor's OSD surface stays mapped. Appearance and confirmed
  progress/thumb changes are immediate; dismissal and decorative motion may
  animate. Do not animate both the fill and a thumb bound to that fill.
- Audio effects reuse one PipeWire control connection on a dedicated thread.
  The first request runs immediately; only already-queued, same-direction
  repeats are coalesced. Replies still carry verified state, not optimistic
  values. Failed effects are never automatically replayed.
- LED hardware notifications (`brightness_hw_changed`/`POLLPRI`) wake the daemon
  where supported. A 50 ms cached-file fallback covers other drivers and
  software writes; device discovery runs every five seconds. Extremely brief
  transitions can still be missed by the fallback. No raw keyboard access or
  extra input-device permissions are required.

Regression coverage: `tests/qml/tst_bar_osd_responsiveness.qml` checks immediate
progress updates with animations enabled and reappearance during dismissal.
The daemon's isolated PipeWire test uses only virtual devices:
`cargo test --lib private_pipewire_control -- --ignored --nocapture`.

## Timeout policy

| Family | Timeout |
| --- | ---: |
| Volume, microphone, brightness, lock keys, keyboard backlight | 1400 ms |
| Power profile, idle inhibitor, audio/display device | 2200 ms |
| Camera and microphone privacy, brightness errors | 3000 ms |

The policy is centralized in `BarPresentation.osdTimeout()`. A new OSD family should extend that function instead of introducing another QML timer or frame.

## Ownership boundary

`bar-daemon` owns native system observation and normalized durable/current state. Its `osd-hardware.changed` stream reads Linux LED-class state for lock indicators, keyboard backlight, and available camera/microphone privacy indicators. Missing hardware is represented as unavailable or `null`, not synthesized by QML.

Shelllist owns transition detection, text, icons, progress visibility, timeout choice, monitor-local rendering, and nonessential animation. QML must not poll sysfs, D-Bus, PipeWire, MPRIS, or compositor state for OSD events.

## Adding an OSD

1. Add or reuse a normalized daemon/API state field and checked stream contract.
2. Add a pure descriptor helper in `bar/BarOsdPresentation.js`.
3. Add transition selection to `domainOsd()` or present the descriptor only after a successful operation response.
4. Reuse `BarController.presentOsd()` and `BarOsdContent.qml`; do not add a parallel window or timer.
5. Add presentation-policy and API-contract assertions.

Focused validation:

```sh
node tests/check-bar-presentation.js bar/Bar{Workspace,Media,Osd,Status}Presentation.js \
  qml/Shelllist/Core/Duration.js
nix build .#checks.x86_64-linux.barDaemonContract
shelllist-qmllint bar/*.qml
nix flake check
```
