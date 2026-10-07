# Application resources

Resources uses four equal, information-only snapshot cards above larger evidence
plots: **Activity, Memory, Disk, Network**. Cards reflow to 2×2 below 620 logical
px × uiScale. They never become buttons or editable fields. There is no definitions,
caveats or Measurement details panel, information command, or hover explanation.
Full metric identities and retained statistics remain in static accessible names.

## Snapshot and evidence

- **Activity:** vertically stacked CPU machine-capacity and GPU engine-activity
  percentages, distinguished by processor/board glyphs. They are never summed.
  History uses separate interval-column lanes with the same percentage scale and
  time window. The glyphs match the snapshot; no repeated heading or scale caption.
- **Memory:** RAM headline, GPU resident bytes as a smaller board-glyph reading.
  GPU memory is not added to RAM. Only RAM gets a history plot: an unstacked,
  zero-based step area with a visible byte scale. Its glyph replaces the RAM label.
  The snapshot source is PSS or RSS fallback; historical samples do not record
  that source and must not inherit it from a later snapshot.
- **Disk:** identified app-data bytes above glyph-led read/write rates. Below the
  cards, a drive glyph and separate archive/clock-folder bars show persistent and
  temporary amounts on one zero-based byte scale. Valid parts remain independent
  when another component or the total is unavailable. Zero bars have no fill.
  Installation/shared dependencies are not measured; referenced-file observations
  may overlap or be shared and are never added. Temporary is not safe-to-delete.
  These scope rules remain authoritative even without visible routine caveats.
- **Network:** stacked receive/send rates. Evidence is two positive horizontal bars
  for estimated selected-period transferred bytes, on the same explicit byte
  scale, with distinct direction glyphs and a patterned send bar. It is not another
  rate timeline, a quota or a connection-capacity gauge.
- **CPU-package power:** one unboxed bolt/value row under the cards, not a fifth
  snapshot card or another curve. Power remains RAPL-attributed CPU-package power,
  not whole-machine electricity, battery drain or a battery-life prediction.
  Current/period confidence and estimated period energy remain accessible. No
  additional definition or confidence-disclosure UI is introduced.

Disk I/O evidence uses positive paired interval columns: read left, write right,
with one rate scale and independent coverage bands. Footprint, rate and estimated
transfer totals are different quantities, never a shared total or axis. Current
values appear only in the snapshot area. Repeated Snapshot/Evidence/History titles,
RAM observation footer and the old measurement command are removed. The shared
range control sits above history, below current power and disk breakdown.

Direction glyphs mean down = read/receive, up = write/send. Domain headings remain
on the four cards and lower Disk I/O/Network evidence cards. Glyphs, pattern and
position distinguish series independently of color. Full names, units, sources,
scale limits, mean/peak and observation time remain in accessible summaries.

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
plots/totals; current snapshot cards remain independent.

Observed/selected duration is shared only for series with identical coverage;
otherwise show the per-direction/per-series durations. Network totals retain their
own coverage; the footer reports Activity/I/O coverage. RAM coverage is accessible
and its gaps remain visible. Process coverage is distinct: reduced/unknown process
coverage, shared attribution and nonzero swap stay visible as exception messages.

There is no live-snapshot timestamp in the API. Do not invent age or freshness.
The running-app snapshot needs no routine caption; stopped apps show a timestamped
retained observation, or explicitly no retained measurements. Sampling interval is
not snapshot age. Existing domain errors/loading/recovery remain authoritative.

## Chart geometry

Activity and RAM plots have aligned edges and real timestamp endpoints, never
“Now” on retained data. Activity lanes target 80 logical px each; memory and disk
plots target 96 px, scaled with uiScale. Three horizontal guides replace the dense
vertical tick grid. Readability takes priority over the old compact-height budget;
use the normal page scroller. Disk/Network evidence reflows to one column below
560 logical px × uiScale. Values wrap rather than elide; long reasons grow cards.

All history styles consume `ApplicationResources.historySegments`. Buckets end at
`timestamp_ms` and cover their preceding positive `duration_ms`. The helper clips
both edges, rejects invalid durations/duplicate ends, bounds overlapping buckets,
and breaks at unsupported/unobserved intervals. No carry-forward, smoothing over
gaps or zero substitution. Memory steps represent bucket readings, not exact
allocation-event timestamps. Column width follows observed duration; paired columns
split that bucket's width rather than extending into neighbouring missing time.
Measured zero has zero column height, not a decorative minimum-height pulse.

Single-series lanes hatch missing time across their plot. Paired disk directions
have separate thin coverage bands below the positive baseline, so one unavailable
direction cannot hatch over the other's valid bars. Canvas repaint clears old marks
before rendering newly unavailable intervals. Empty/loading plots use shared
`ContentState`; partially retained history stays visible.

## Interaction and validation

The [shared keyboard contract](chooser-keyboard-workflow.md) remains authoritative.
The range selector is the sole editable stop. Enter saves; Escape discards;
Tab/Shift+Tab save and wrap while continuing editing. Pointer choices remain drafts
until saved. Source bindings, focus and drafts survive arriving snapshots. Cards,
glyphs, bars, scales and statistics are passive and add no navigation commands.
PageUp/PageDown scroll the containing page while browsing. There is no new chart
inspection mode, Alt+H measurement command, cleanup action or info disclosure.

`tests/qml/tst_application_resources.qml` covers actual Qt key/pointer transactions,
passive glyphs, four-card/reflow geometry, page scrolling, arriving snapshots during
a draft, independent metric availability, stopped/loading/zero states, canonical
transfer totals, separate gap geometry and Canvas paired-column pixels. JavaScript
checks retain precision, weighting/window/coverage validation and interval clipping:

```sh
node tools/build-typescript.mjs --check
node tests/check-application-resources.js launcher/ApplicationResources.js contracts/app-resource-ui-contract.fixture.json
node tests/check-resource-availability.js
tests/run-qmlquality-tests.sh -input tests/qml/tst_application_resources.qml
tests/run-qmllint.sh
```
