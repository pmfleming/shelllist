// Bundled for QML by nix/material-colors.nix. No DOM, I/O or runtime dependencies.
import { argbFromRgb, hexFromArgb, Hct, SchemeTonalSpot, TonalPalette } from '@material/material-color-utilities';

const roles = [
    'primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer',
    'secondary', 'onSecondary', 'secondaryContainer', 'onSecondaryContainer',
    'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer',
    'surface', 'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer',
    'surfaceContainerHigh', 'surfaceContainerHighest', 'onSurface', 'onSurfaceVariant',
    'outline', 'outlineVariant', 'error', 'onError', 'errorContainer', 'onErrorContainer'
];
// Material has no success/warning roles. These extensions use the same HCT
// implementation and foreground/background tones, not hand-blended RGB colors.
const success = TonalPalette.fromHueAndChroma(145, 36);
const warning = TonalPalette.fromHueAndChroma(85, 36);

export function createScheme(red, green, blue, dark) {
    const channel = value => Math.round(Math.max(0, Math.min(1, value)) * 255);
    const source = Hct.fromInt(argbFromRgb(channel(red), channel(green), channel(blue)));
    // Pin the color spec as well as the package: dependency upgrades must not
    // silently change contrast/role semantics. Expressive styling is separate.
    const scheme = new SchemeTonalSpot(source, dark, 0, '2021');
    const colors = {};
    for (const role of roles) colors[role] = hexFromArgb(scheme[role]);
    for (const [name, palette] of [['success', success], ['warning', warning]]) {
        colors[name] = hexFromArgb(palette.tone(dark ? 80 : 40));
        colors['on' + name[0].toUpperCase() + name.slice(1)] = hexFromArgb(palette.tone(dark ? 20 : 100));
    }
    return colors;
}
