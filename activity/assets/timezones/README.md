# World timezone map

`world-time-zones.svg` and `../../TimezoneGeometry.js` are generated from the
[Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder)
2026c `timezones-now` dataset. The project derives IANA timezone boundaries
from OpenStreetMap and publishes generated data under the
[Open Data Commons Open Database License](https://opendatacommons.org/licenses/odbl/).

The source geometry was simplified for the compact Shelllist view. The muted
sea uses the canonical 15-degree whole-hour UTC bands seen on reference maps,
while brighter land polygons preserve their IANA geographic boundaries.
`TimezoneGeometry.js` retains land paths plus IANA offset transitions for
2020–2050, allowing every region at the selected current UTC offset to be
highlighted without network access. Land is masked out of the sea bands so
political offsets and fractional-hour regions remain separate.

The generated presentation was compared against the
[timeanddate.com Time Zone Map](https://www.timeanddate.com/time/map/) and the
public-domain Wikimedia Commons
[Time Zones of the World](https://commons.wikimedia.org/wiki/File:World_Time_Zones_Map.svg)
reference. Country/city labels and political borders are omitted.
