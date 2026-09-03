# World timezone map

`world-time-zones.svg` and `../../TimezoneGeometry.js` are generated from the
[Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder)
2026c `timezones-now` and `timezones-with-oceans-now` datasets. The project derives IANA timezone boundaries
from OpenStreetMap and publishes generated data under the
[Open Data Commons Open Database License](https://opendatacommons.org/licenses/odbl/).

The source geometry was simplified for the compact Shelllist view. Muted ocean
regions continue each timezone from the north to south map edges, while brighter land polygons
preserve their geographic boundaries. `TimezoneGeometry.js` retains complete
land-and-ocean paths plus IANA offset transitions for 2020–2050, allowing every
region at the selected current UTC offset to be highlighted without network
access. Fractional-hour regions remain separate. Country/city labels and
political borders are omitted.
