# Application resources

The Resources details page answers four different questions, without combining
incompatible units into an overall score. The approved visual study is
[application-resources.html](proposals/application-resources.html).

## Overview

- **Space on disk:** identified app-directory data, with persistent and temporary
  amounts shown separately. The optional bar is composition, not disk capacity.
  Installation files and shared dependencies are **not measured**. Referenced
  files are separate, potentially overlapping/shared observations, never added
  to the app-data total. Temporary does not mean safe to delete.
- **Using right now:** RAM (PSS or explicitly labeled RSS fallback), swap,
  resident/allocated GPU memory, CPU as a percentage of total machine capacity,
  and GPU engine busy time. GPU memory is not added to RAM.
- **Energy:** attributed CPU-package power in W and estimated energy in mWh/Wh
  for the selected period. Source and confidence remain visible. This is not
  whole-system electricity, battery drain, or a battery-life forecast. The period
  confidence is the weakest known confidence in its valid retained energy
  samples (unknown when not established).
- **Data moved:** separate disk read/write and network receive/send rates, with
  estimated period totals and per-metric observed time. Memory bandwidth is not
  collected; neither occupied RAM nor logical file I/O measures DRAM bandwidth.

The current API has no timestamp for each live application snapshot, so the page
says **latest application snapshot**, not a made-up age or “live” freshness
promise. The sampling interval is labeled as such, not as snapshot age. Stopped
applications use a timestamped retained observation, or explicitly report no
retained measurements. Historical samples do not identify their PSS/RSS source;
the page does not infer it from another snapshot.

Availability requires both the domain capability and a finite, nonnegative
numeric value. Missing, null, invalid, or unsupported readings are not zero.
Available small positive power below 0.01 W displays `<0.01 W`; an actual zero
remains `0.00 W`. Network connection attribution does not establish byte
attribution. Battery-source power is not accepted as per-app energy.

## Period estimates and history

The shared 30m / 2h / 24h field controls both period estimates and history. A
summary is usable only when its window matches the controller's selected
window and its weighting is `observed-duration`.

The daemon's canonical summary is independent of history pagination and clips
bucket durations to the requested window. The UI derives:

- estimated bytes = mean bytes/second × observed milliseconds / 1,000;
- estimated mWh = mean watts × observed milliseconds / 3,600.

These are labeled `≈` because the retained rates are rounded and boundary
buckets represent averages. Only valid observed intervals contribute. A missing
summary, unknown weighting, unavailable mean, or zero/invalid/excessive observed
duration produces **Unavailable**, never a fabricated total. Refreshing the
range shows a loading state rather than reusing a different window's totals.
No lifetime counters are summed; process counter resets remain owned by the
daemon. Installation attribution and new memory-bandwidth collectors are not
part of this frontend change.

History retains a common time axis, independent labeled y-scales, and readable
current/average/peak values. At narrower widths each chart moves below its value
and statistics rather than eliding them. Read/receive and write/send have
opposite directions in paired lanes. The range end is an actual timestamp,
not a “Now” label on retained data. Buckets end at `timestamp_ms` and cover the
preceding `duration_ms`; unsupported buckets and unobserved intervals break
traces. Summary reference lines do not cross missing-data regions.

Process attribution coverage and temporal observation coverage are distinct.
The metadata badges describe process attribution; each history lane and period
estimate describes its own observed duration. A network collector can be
unavailable while CPU and disk remain measured.

## Interaction and validation

The [shared keyboard contract](chooser-keyboard-workflow.md) is unchanged.
The range selector is the only editable field in Resources. Overview cards,
metadata and history are read-only, not browsing stops. The shared segmented
control owns save/discard, pointer drafts, forward/reverse wrapping and source
binding restoration. No cleanup, launch, or other command is added.

`tests/qml/tst_application_resources.qml` delivers actual Qt keys and pointer
input to the resource page inside `ProviderChooserSurface`. It verifies
save/discard/query boundaries, editable-only traversal, retained/unavailable
states, scoped totals and narrow-layout value geometry. The JavaScript resource
checks cover strict availability, power precision, summary-window validation,
partial observation estimates and canvas gap handling. Run:

```sh
node tools/build-typescript.mjs --check
node tests/check-application-resources.js launcher/ApplicationResources.js contracts/app-resource-ui-contract.fixture.json
node tests/check-resource-availability.js
tests/run-qml-tests.sh
tests/run-qmllint.sh
```
