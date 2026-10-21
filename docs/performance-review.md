# Performance review — external Rust lens

## Baseline and limits

The release lens captured the existing deployed Shelllist session without opening,
hiding or editing panels. Baseline run: `1792621617180-449244-0` under
`tools/performance-lens/runs/` (ignored local raw JSON/HTML). Protocol: 3 s settling,
20 s observation, 1 s procfs cadence, 5 s PSS/DRM cadence, explicit UI service
members and five related daemon services. No builds ran during this capture.

| Scope | CPU, percent of one core | Sampled peak RSS |
| --- | ---: | ---: |
| Quickshell UI | 0 observed ticks | 393.8 MiB |
| bar-daemon | 96.83% | 72.9 MiB |
| app-daemon | 2.30% | 527.6 MiB |
| nm / bt / clip daemons | 0.25 / 0.15 / 0.10% | Separate raw rows |
| Lens observer | 0.95% | 5.7 MiB |

RSS is not unique physical memory; sampled zero ticks are not proof of zero work.
Related daemons serve other clients. This is an uncontrolled live-session triage
capture, not a statistically certified baseline. The deployed QML config is the
Nix store path recorded in the manifest, not the current checkout. No daemon was
restarted or desktop deployment activated. Follow-up timings below are isolated
synthetic operations and must not be labelled input-to-photon improvements.

The previously implemented lens was committed first as a prerequisite (`fa09657`).
Each numbered improvement has its own implementation commit(s); synchronized
vendored search changes also require a separate clip-daemon repository commit.

## 1. Stop Updates watches traversing build-cache closures

**Owner:** bar-daemon, commit `0b91219`.

The busy thread was `notify-rs inoti`. The manual rebuild ledger watcher recursively
followed `check-cache/*/checks` links into Nix store closures, despite reading only
flat ledger files. The manual watcher is now nonrecursive; the worker watcher
still covers real history/job directories but no longer follows symlink targets.
No acknowledgement, publication, debounce or recovery policy was removed.

Real Linux inotify-registration tests demonstrate that cache trees are no longer
watched and worker subdirectories still are. The new ledger test failed before the
fix; all 44 Updates tests pass afterward. A fixed 25-registration probe with a
1,000-directory synthetic cache symlink took **371.785 → 3.318 ms** in the same
debug profile. This measures registration work, not live CPU after deployment.
See `../bar-daemon/docs/performance-watch-review.md` for reproduction and limits.

## 2. Avoid impossible typo-distance calculations

**Owner:** `rust/shelllist-search`, synchronized into clip-daemon's vendored copy.

The ranker calculated full optimal-string-alignment distances for every word,
even when the permitted edit count was zero or the Unicode character-count gap
already exceeded that count. It now skips those impossible candidates while
retaining the fuzzy match path and all ranking/tie-break rules. No query/result
wire changes or panel/navigation changes are involved.

A frozen pre-change scorer checks 24,000 deterministic Unicode/ASCII field/token
pairs. Existing normalization, typo/transposition, all-token matching and queued
query-coalescing tests pass in both copies. A release probe of 25 queries over
1,000 prepared raw catalog rows measured **158.208 → 127.797 ms** (about 19% less
work in this one descriptive run). Fixture construction is outside the timer;
queries still include normalization and ranking. This is not a UI latency percentile.

```sh
cargo test --release --locked --manifest-path rust/shelllist-search/Cargo.toml
cargo test --release --locked --manifest-path rust/shelllist-search/Cargo.toml \
  profile_search_work -- --ignored --nocapture
```
