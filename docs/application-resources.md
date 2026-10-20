# Application resources

Resources uses **History as a list** in the expanded Apps panel: Activity,
Memory, Disk I/O, Network and Power are five passive rows on one low-tone detail
surface. Each row has a concise heading and two labeled readings in a compact
left column; the remaining width belongs to its history. Readings never overlap
plots. Identified app data remains on Application details, not a third power
reading or a sixth resource row.

The list measures its shared label/value columns from font metrics rather than
reserving a percentage of the pane. Desaturated sage/rose, blue/lavender,
sand/green and teal/lavender pairs distinguish metrics and series. Power uses
sand; its energy total is neutral and is not a second plotted series. The shared
Theme owns light/dark variants; Battery and the shell selection accent are
unchanged. Labels, swatches, secondary dashed lines and paired bar positions
retain identities independently of color.

## Viewport layout

The shared `DetailFlickable` remains the navigation/session owner. Five equal-height
rows fill the available viewport, with font-measured minimum heights to keep
readings readable. Short panes scroll through the shared page rather than shrink
or overlap text. The application header and bottom tabs remain outside this budget.

The right-aligned shared range field omits the redundant visible “Range” label,
not its accessible name or edit session. One timestamp axis below the list aligns
with every plot. No repeated history captions, per-row time axes or “Not observed”
text consume chart space. Exceptional page messages use the fixed list footer.

Stable five-row/two-reading repeaters retain instances as descriptors arrive.
Values, availability and accessible names update without interrupting a range
draft. Missing readings show dashes; an unavailable/empty/loading chart uses the
shared compact `ContentState` without hiding valid sibling readings.

## Readings and histories

- **Activity:** current CPU machine-capacity and GPU engine-activity percentages.
  Two lines on a fixed 0–100% scale join only contiguous observations. These
  percentages are never summed.
- **Memory:** current RAM and GPU resident bytes. Both histories retain bucket
  steps on one zero-based byte scale; GPU memory is not added to RAM.
  RAM snapshot source is PSS or RSS fallback. Historical samples do not record
  that source and must not inherit it from a later snapshot.
- **Disk I/O:** estimated selected-period read/write **byte totals**, not current
  rates. Adjacent paired bars show read/write **rates** on a separate rate scale.
- **Network:** estimated selected-period receive/send **byte totals**, with paired
  rate-history bars. This is not a quota or a connection-capacity gauge.
- **Power:** current estimated RAPL-attributed CPU-package watts and estimated
  selected-period energy. Its single-series interval columns show power, not
  energy. It is not whole-machine electricity, battery drain or a battery-life
  prediction. Current and retained-period confidence remain accessible.
- **App data (Application details):** identified directory bytes, independent of
  rates/transfer totals. Total, persistent and temporary values retain independent
  availability. Stopped-app observations must match the history owner identity;
  another app's retained history is never borrowed. This passive card makes no
  new measurement request. Installation and shared
  dependencies are not measured. Referenced-file observations may overlap or be
  shared and are never added. Temporary data is not necessarily safe to delete.

Direction glyphs mean down = read/receive, up = write/send. Glyphs and paired
positions distinguish series as well as color. Full metric identities, current
rates, units, source, mean/peak, scale and observation time remain accessible.
The shared bottom time axis shows actual requested-window timestamp endpoints,
never an invented “Now” on retained data. All microplots use this same window;
they do not share vertical scales across different kinds of measurement.

## Availability, totals and coverage

Availability still requires the domain capability and a finite, nonnegative
numeric value. Missing, null, invalid or unsupported readings are not zero. A
missing series shows a dash without hiding valid siblings; an entirely unavailable
history also shows a concise visible reason. The network byte collector is independent of connection attribution;
valid footprint measurements do not establish disk-I/O availability.

Small positive power below 0.01 W remains `<0.01 W`; real zero remains `0.00 W`.
Battery-source power is never accepted as attributed application power. Current
and period confidence are independent; retained period confidence remains the
weakest known confidence in valid energy samples, or unknown.

The 30m / 2h / 24h shared field controls history and period estimates, never the
latest snapshot. Canonical summaries must match the selected window and use
`observed-duration` weighting. They are independent of history pagination and clip
bucket durations to the requested window:

- estimated bytes = mean bytes/second × observed milliseconds / 1,000;
- estimated mWh = mean watts × observed milliseconds / 3,600.

Visible approximation prefixes are omitted by the approved UI revision, not by
reclassifying measurements as exact. Accessible reading labels retain “Estimated”;
rounded retained rates, boundary-bucket means and confidence remain relevant. Missing/mismatched summaries, invalid means or invalid/zero/excessive
observed durations yield unavailable totals. Do not calculate totals from drawn
bars, sum lifetime counters, or extrapolate over missing intervals. A valid
snapshot can coexist with missing history/totals, and a valid historical estimate
can coexist with an unavailable current reading. Range loading hides old-window
plots/totals; current snapshots remain independent. Shared `ContentState` provides
compact text-only loading/empty states inside the available plot area.

Observed/selected durations, including partial coverage, remain in each row's
accessible summary; there are no visual observation-coverage footers. Missing
intervals still remain gaps in the charts. Process coverage is distinct:
reduced/unknown process coverage, shared attribution and nonzero swap stay visible
through concise shared-footer contributions without resizing the resource list.

There is no live-snapshot timestamp in the API. Do not invent age or freshness.
The running-app snapshot needs no routine caption; stopped apps show a timestamped
retained observation, or explicitly no retained measurements. Sampling interval is
not snapshot age. Existing domain errors/loading/recovery remain authoritative.

## Chart geometry

All plots reuse `ApplicationResourcePlot` and `ApplicationResources.historySegments`.
Buckets end at `timestamp_ms` and cover their preceding positive `duration_ms`.
The helper clips both edges, rejects invalid durations/duplicate ends, bounds
overlapping buckets, and breaks at unsupported/unobserved intervals. No carry-
forward, smoothing over gaps or zero substitution. Column width follows observed
duration; paired columns split the bucket width rather than extending into
neighbouring missing time. Measured zero gets only a baseline mark, not a
decorative pulse. Lines stop at each segment boundary; memory is not smoothed.

Two subtle horizontal guides identify the baseline and scale maximum. Intervals
unobserved by every series have faint background shading, with no repeated gap
text or hatch. Missing series remain independently unpainted; another series'
valid interval is never shaded as missing. Gaps are never filled with zero,
interpolated or carried forward. Canvas repaint clears old marks before rendering
newly unavailable intervals. Coverage, scales and independently missing series
remain available to accessibility.

## Interaction and validation

The [shared keyboard contract](chooser-keyboard-workflow.md) remains authoritative.
The range selector is the sole editable stop. Enter saves; Escape discards;
Tab/Shift+Tab save and wrap while continuing editing. Pointer choices remain drafts
until saved. Source bindings, focus and drafts survive arriving snapshots. Rows,
glyphs, bars, scales and statistics are passive and add no navigation commands.
Page keys retain shared semantics and scroll short panes. There is no chart
inspection mode, cleanup action or info disclosure.

Resource presentation and parser permutations were retired in the
[ownership reduction](../tests/test-reduction-owners.md). Native daemon tests retain
resource aggregation, ownership, bounded work, clipped available totals, history
persistence and shutdown. Shared fields retain input transactions; they do not
prove resource-specific chart paint or GPU/network telemetry permutations. The
earlier normal/minimum and light/dark captures remain historical manual evidence.

Implementation review evidence is local under `target/resource-history-list/`:
Qt-rendered dark/light active histories, normal/minimum full detail captures,
strict lint and the full Qt suite. Synthetic captures are not live telemetry;
they do not claim a human screen-reader or hardware accessibility review.

```sh
node tools/build-typescript.mjs --check
tests/run-qml-tests.sh
tests/run-qmllint.sh
```
