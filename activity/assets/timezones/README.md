# World timezone map

`world-time-zones.svg` and the SVGs under `regions/` are generated from the
[Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder)
2026c `timezones-now` dataset. The project derives IANA timezone boundaries
from OpenStreetMap and publishes generated data under the
[Open Data Commons Open Database License](https://opendatacommons.org/licenses/odbl/).

The source geometry was simplified for the compact Shelllist view. The muted
sea uses the canonical 15-degree whole-hour UTC bands seen on reference maps,
while brighter land polygons preserve their IANA geographic boundaries. The
Rust `bar-daemon` resolves current offsets with `chrono-tz` and returns the
matching region asset IDs. QML loads those static overlays instead of parsing
geometry or timezone transitions as JavaScript. Opaque land remains above the
sea highlight so political offsets and fractional-hour regions stay separate. Regenerate the
checked overlays after changing the base map with:

```bash
nix run .#shelllistTimezoneAssets -- \
  activity/assets/timezones/world-time-zones.svg \
  activity/assets/timezones/regions
```

The generated presentation was compared against the
[timeanddate.com Time Zone Map](https://www.timeanddate.com/time/map/) and the
public-domain Wikimedia Commons
[Time Zones of the World](https://commons.wikimedia.org/wiki/File:World_Time_Zones_Map.svg)
reference. Country/city labels and political borders are omitted.
