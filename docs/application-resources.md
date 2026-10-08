# Application resources

Resources uses five passive **integrated microcards** in the expanded Apps panel:
Activity and Memory on the first row, Disk I/O and Network on the second, and
CPU-package power/energy across the third. Identified app data occupies the right
end of the power card, rather than a mostly empty sixth card. Each card places
compact icon/value pairs beside its history. Disk/network domain icons are
vertically centered next to their direction readings. There are no repeated
card titles, separate snapshot/evidence sections or measurement commands.

## Viewport layout

The shared `DetailFlickable` remains the navigation/session owner, but its sole
resource child takes the **viewport height**, not the implicit height of stacked
charts. The range selector, timestamp axis and exceptional status messages take
their natural heights; the 2×2 + full-width grid divides the remaining height into
three equal rows. Cards and plots grow/shrink with the expanded panel and do not
impose content-sized minimum heights. There is no resource scrolling at supported
expanded chooser sizes. The real application header and bottom tab bar remain
outside this budget. No panel-local keyboard model or artificial clipped scroll
area is introduced.

Stable five-card/two-reading repeaters retain instances as descriptors arrive.
Values, availability and accessible names update without rebuilding plots or
interrupting a range draft. Normal labels are icons; exceptional unavailable,
loading, reduced coverage, shared attribution and nonzero swap remain visible.
Repeated missing readings share one short card status, while their individual
dashes and accessible names identify which values are unavailable.

## Readings and integrated bars

- **Activity:** current CPU machine-capacity and GPU engine-activity percentages.
  One paired-column history on a fixed 0–100% scale, CPU left/GPU right. These
  percentages are never summed.
- **Memory:** current RAM and GPU resident bytes. Both histories use paired
  interval columns on one zero-based byte scale; GPU memory is not added to RAM.
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
- **App data:** identified directory bytes, independent of rates/transfer totals.
  The compact folder/value keeps persistent and temporary component values and
  their availability in its accessible description. Installation and shared
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
missing series shows a dash and a short visible reason without hiding valid
siblings. The network byte collector is independent of connection attribution;
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

The approximation prefix reflects rounded retained rates and boundary-bucket
means. Missing/mismatched summaries, invalid means or invalid/zero/excessive
observed durations yield unavailable totals. Do not calculate totals from drawn
bars, sum lifetime counters, or extrapolate over missing intervals. A valid
snapshot can coexist with missing history/totals, and a valid historical estimate
can coexist with an unavailable current reading. Range loading hides old-window
plots/totals; current snapshots remain independent. Shared `ContentState` provides
compact text-only loading/empty states inside the available plot area.

Partial observed/selected durations appear in the affected card, per series.
Full coverage stays accessible without a routine footer. Process coverage is
distinct: reduced/unknown coverage, shared attribution and nonzero swap stay
visible below the grid and participate in the viewport budget.

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
neighbouring missing time. Measured zero has zero height, not a decorative pulse.

Subtle horizontal guides replace vertical ticks. Single-series lanes hatch missing
time across the plot. Paired series have separate thin coverage bands below the
positive baseline, so one unavailable direction cannot hatch over another's valid
bars. Canvas repaint clears old marks before rendering newly unavailable intervals.
Partial history remains visible; scales and independently missing series remain
available to accessibility.

## Interaction and validation

The [shared keyboard contract](chooser-keyboard-workflow.md) remains authoritative.
The range selector is the sole editable stop. Enter saves; Escape discards;
Tab/Shift+Tab save and wrap while continuing editing. Pointer choices remain drafts
until saved. Source bindings, focus and drafts survive arriving snapshots. Cards,
glyphs, bars, scales and statistics are passive and add no navigation commands.
Page keys retain shared semantics; a viewport-fitted Resources page has no scroll
distance. There is no chart inspection mode, cleanup action or info disclosure.

`tests/qml/tst_application_resources.qml` checks real Qt keyboard and pointer
transactions, arriving snapshots during a draft, independently available totals,
loading-window transitions, combined CPU/GPU and RAM/GPU bars, and five-card
geometry inside the **real application detail header/tab stack** at compact,
standard and large expanded sizes. It verifies no scrolling, usable plot space,
contained readings and growth on resize. JavaScript tests retain precision,
weighting/window/coverage validation and interval clipping.

```sh
node tools/build-typescript.mjs --check
node tests/check-application-resources.js launcher/ApplicationResources.js contracts/app-resource-ui-contract.fixture.json
node tests/check-resource-availability.js
tests/run-qmlquality-tests.sh -input tests/qml/tst_application_resources.qml
tests/run-qmllint.sh
```
