# World timezone map

`world-time-zones.svg` and `../../TimezoneGeometry.js` are generated from the
[Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder)
2026c `timezones-now` and `timezones-with-oceans-now` datasets. The project derives IANA timezone boundaries
from OpenStreetMap and publishes generated data under the
[Open Data Commons Open Database License](https://opendatacommons.org/licenses/odbl/).

The source geometry was simplified for the compact Shelllist view. Muted ocean
regions continue each timezone from the north to south map edges, while brighter land polygons
preserve their geographic boundaries. `TimezoneGeometry.js` retains the land
paths and IANA aliases so the selected timezone can be highlighted without
network access. Country/city labels and political borders are omitted.
