# System version comparison

Updates → Now → System shows passive Linux kernel and Hyprland rows with
installed and latest stable upstream versions. Installed means package metadata
from the active generation's inventory; it does not claim the running kernel or
compositor has restarted. Booted, active and next-boot paths remain separate.
Only system-scope packages contribute; a user's similarly named package cannot
replace the system version. Missing inventory or release evidence stays explicit.

The host's `/etc/nixos/modules/application-inventory.nix` includes the selected
`boot.kernelPackages.kernel` even though it is not an environment package. Its
inventory name is `linux`, including patched flavours, with the real package
version/store path. Disabled kernels are excluded. Hyprland uses the existing
system package inventory and reviewed GitHub stable-release mapping.

The update worker's `kernel-stable` source reads kernel.org's `releases.json`.
It accepts the numeric `latest_stable.version` only with a matching non-EOL
stable/final-mainline release. It never chooses an RC, linux-next or a branch's
LTS patch by sorting all release entries. Latest upstream need not be the version
selected by the host's Nix pins or kernel branch. The existing bounded scheduled
release checker caches observations, retains last-known values after failure,
and keeps timestamps/source/diagnostics. Deploy worker and host inventory together:
older workers reject new provider identities.

The panel only reads the existing overview projection. Stale/failed cached values
say “Last known stable”; source, check time and errors remain in shared Help and
accessibility descriptions. Shared FormField/FieldRow composition adds no editable
Tab stops. Opening, scrolling, switching tabs or refreshing does not fetch releases
or perform updates. Deployment, approval, retry and recovery guards are unchanged.

Evidence owners: `tests/qml/tst_updates.qml` exercises native navigation and version
refresh/missing data; update-worker `application_releases` tests cover provider
validation, cache publication/failure retention and metadata-only reads; the host's
`config/scripts/tests/application-inventory.nix` checks actual selected packages,
patched-kernel identity and disabled-kernel omission.

Validation (2026-11-07): Updates Qt suite 49 passed (offscreen/software renderer),
worker release/inventory suite 12 passed, worker Clippy clean, and host inventory
assertions passed against the evaluated ThinkPad configuration. Changed QML files
pass scoped lint. Full QML lint stops on existing unqualified `controller` access
in `bar/BarBackend.qml`. The panel role review found no new numeric overrides;
the new card uses shared semantic roles and adds no local setting wrapper.
No full Nix package build, live activation or running-compositor restart was done.
