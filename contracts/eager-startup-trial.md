# Eager daemon startup — selected local trial

2026-10-28: the user selected **start all five daemons at graphical login**, including
Applications, and observe their resource use. Applications does not require an
on-demand exception for this trial. This resolves the local trial's startup-policy
choice, not general release readiness or a universal deployment default.

The user subsequently confirmed socket selection for all five daemons at the next
startup and chose **manual btop observation**, not an automated login resource
recorder. The installed `shelllist.service`, as well as its declarative source,
already sets all five `SHELLLIST_*_SOCKET=1` flags. Current-boot service logs also
confirm `socket=true` starts for BT, NM, App, Bar and Clip. There is no pending
transport configuration switch: the next login will retain this local opt-in.
No live restart, rebuild or package-default change was performed. This approval
does not claim that the separate startup compatibility/readiness gates are closed.

## Existing deployment already implements the choice

Read-only inspection of this user's effective configuration found:

- `app-daemon`, `bar-daemon`, `bt-daemon`, `clip-daemon` and `nm-daemon` are enabled,
  running, and wanted by / part of `graphical-session.target`.
- `/etc/nixos/home.nix` owns the deployment. It installs the app/BT/Clip/NM packaged
  units and graphical-session enablement links with UWSM session drop-ins. Bar's
  imported Home Manager module owns its unit. These are independent services,
  not children started or stopped by the Shelllist UI.
- All five exact socket opt-ins are already present in the deployed Shelllist
  configuration. This observation is not permission to change package defaults.
- The clipboard engine (`ringboard-server.service`) is independently running and
  included in the resource observation. `ringboard-wayland.service` is inactive;
  no collector/privacy/notification policy was changed to perform this trial.

No unit enablement, configuration edit, service restart, rebuild, activation,
logout or reboot was necessary or performed. The observed services started earlier
in this session; this inspection does not prove a new login's ordering/readiness.
The unrelated `wayland-wm-app-daemon.service` is not Shelllist's Applications daemon.

## Observation and remaining gates

[The initial resource baseline](../tests/eager-startup-resources.md) records a
read-only one-minute live-session sample, with per-service CPU, proportional
memory and cgroup accounting. Resource usage is measured rather than assumed low.
Applications should be watched especially for background CPU and memory growth.

A subsequent actual login can qualify cold-start ordering, time to usable sockets,
resource peaks and settled background cost. That requires observing a real login;
this task does not force one or claim it happened. Compare matching packages and
workloads, include clipboard helpers, and distinguish cumulative CPU from interval
CPU and cgroup cache charges from process memory. Short live observations do not
establish idle power draw, regression significance or sustained-load acceptance.

The [startup design](socket-startup-design.md) remains applicable for compatibility
before effects, bounded readiness, healthy-peer isolation and upgrade/rollback.
Those gates are not implemented or waived by eager startup. Systemd inherited
listener/socket activation is not selected. Non-systemd/multi-session policy and
other deployments' composition remain separate decisions.
