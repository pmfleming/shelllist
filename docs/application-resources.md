# Application resources

The Resources page combines latest readings and history into five compact,
read-only groups. The approved density study is
[application-resources-compact.html](proposals/application-resources-compact.html).
It replaces the separate overview-card stack followed by repeated history values.
Incompatible units are never combined into a score or stacked total.

## Compact groups

- **Activity:** CPU and GPU latest percentages beside solid/dashed line traces
  on one explicitly labeled adaptive percentage scale. CPU measures total-machine
  capacity; GPU measures engine busy time. They are not summed.
- **Memory:** RAM and GPU resident bytes beside unstacked step traces, on one
  byte scale. Current PSS/RSS-fallback source stays visible; nonzero swap adds an
  exception label. GPU resident history is drawn only when retained samples have
  an available numeric value. Older/missing GPU history does not hide a valid
  snapshot or RAM history. No new collector or assumed summary is required.
- **Storage:** identified app-data total and a slim persistent/temporary
  composition strip, followed by paired disk read/write rates and diverging
  interval columns. The strip is composition, not disk capacity. Zero has an
  empty outline, not a full bar. Installation/shared dependencies are **not
  measured**. Referenced files may overlap or be shared and are never added.
  Temporary does not mean safe to delete. Disk I/O is traffic, not footprint.
- **Network:** receive/send rates and diverging areas. Both directions retain
  their own estimated period totals and availability. A missing byte collector
  does not mean zero traffic, even if connection attribution is available.
- **CPU-package energy:** attributed power in W beside an area trace, with
  estimated period energy in mWh/Wh. RAPL source and confidence remain visible;
  latest and period confidence appear separately when different. This is not
  whole-system electricity, battery drain or a battery-life forecast. Period
  confidence is the weakest known confidence in valid retained energy samples,
  or unknown when not established.

Direction glyphs replace repeated labels: down = read/receive, up = write/send.
Read/receive are above the centre line and write/send below; the lower half
encodes positive magnitude, not negative traffic. Colors plus solid/dashed
strokes or position distinguish series. Full metric names remain accessible.

Latest values appear once. Average/peak, swap, GPU allocation, persistent and
temporary amounts, referenced files, sampling interval, attribution method,
shared attribution, retained sample counts and explanations are available in
**Measurement details**. GPU memory is never added to RAM. Memory bandwidth is
not measured; neither occupied RAM nor logical file I/O represents DRAM bandwidth.

There is no live-snapshot timestamp in the API: the caption says **Latest
snapshot**, not an invented age or live-freshness guarantee. Stopped apps show a
timestamped retained observation or explicitly no retained measurements.
Historical samples do not record their PSS/RSS source; it is not inferred from
another snapshot. Sampling interval is not snapshot age.

## Availability, totals and coverage

Availability requires both the relevant domain capability and a finite,
nonnegative numeric value. Missing, null, invalid or unsupported readings are
not zero. Small positive power below 0.01 W remains `<0.01 W`; an actual zero is
`0.00 W`. Battery-source power is never accepted as attributed application energy.

The shared 30m / 2h / 24h field controls history and period estimates. A canonical
summary is usable only if its window matches the selected window and its
weighting is `observed-duration`. It is independent of history pagination and
clips bucket durations to the requested window. The UI derives:

- estimated bytes = mean bytes/second × observed milliseconds / 1,000;
- estimated mWh = mean watts × observed milliseconds / 3,600.

The `≈` prefix reflects rounded retained rates and boundary-bucket means. Only
valid observed intervals contribute. A missing summary, unknown weighting,
unavailable mean or invalid/zero/excessive observed duration produces
**Unavailable**, never a fabricated total. Range refresh hides plots and period
estimates behind loading states instead of showing another window's data. Valid
latest snapshot readings remain separate. No lifetime counters are summed;
process-counter resets remain daemon-owned.

`◷ 24m/30m` means observed/selected time. A group shares this badge only when its
series have identical observed durations; otherwise each series gets its own
value. Process attribution coverage is separately labeled below the groups,
alongside any shared-attribution warning. Static accessible summaries and the
statistics disclosure retain full observation descriptions and average/peak
values even though the main chart rows do not repeat them visually.

## Chart geometry

All groups use one selected time window, aligned plot edges and a common bottom
time axis ending at an actual timestamp, never “Now” on retained data. Each
group has its own visible y-scale. Narrow panes stack plots below values instead
of clipping numbers. Larger text and unavailable reasons may increase height.
The compact layout targets roughly 640–720 logical px at 620–720 px pane widths;
correctness and legibility take precedence over that budget.

Buckets end at `timestamp_ms` and cover their preceding positive `duration_ms`.
The shared `ApplicationResources.historySegments` helper clips both window edges,
rejects invalid durations/duplicate ends, bounds overlapping buckets, and breaks
at unsupported or unobserved intervals. All Canvas styles consume those same
segments. No carry-forward, smoothing across gaps, or zero substitution is used.
Memory steps describe bucket readings, not exact allocation-event timestamps.
Disk columns use the bucket duration as width and average B/s as height; a
minimum-width bar never extends into missing time. Totals use the canonical
summary, not the rendered geometry.

Hatched gaps are per series. Paired plots shade the relevant upper/lower half;
overlaid traces have separate thin coverage bands (first series above second),
so one unavailable series cannot obscure a valid one. With no retained readings,
the plot collapses; wholly unavailable groups retain their identity and reason.
Current unavailability does not hide valid retained history.

## Interaction and validation

The [shared keyboard contract](chooser-keyboard-workflow.md) remains authoritative.
The range selector is the only editable field. Enter saves, Escape discards, and
Tab/Shift+Tab save and wrap while continuing editing. Pointer range choices stay
local drafts until save; source bindings survive cancellation and external updates.
Charts, statistics, metadata and explanatory text are not field stops.

**Alt+H** and the icon-only shared information command toggle Measurement details.
The same disclosure is available by name through the shared Alt+J content menu.
Opening reveals its heading when it is outside the viewport; PageUp/PageDown
scroll the read-only page. It has no backend side effects, does not add an editor,
and resets on application identity changes. No cleanup/launch action or chart
inspection keyboard model is introduced.

`tests/qml/tst_application_resources.qml` delivers actual Qt key and pointer input
inside `ProviderChooserSurface`. It covers range transactions, command/menu
modality, read-only disclosure and scrolling, field-only wrapping, retained and
unavailable states, independent trace gaps, loading, zero composition and compact/
narrow geometry. JavaScript tests exercise strict availability, power precision,
summary-window validation, observed-time estimates, clipped/overlapping bucket
geometry, duplicate timestamps and per-direction gaps. Run:

```sh
node tools/build-typescript.mjs --check
node tests/check-application-resources.js launcher/ApplicationResources.js contracts/app-resource-ui-contract.fixture.json
node tests/check-resource-availability.js
tests/run-qml-tests.sh
tests/run-qmllint.sh
```
