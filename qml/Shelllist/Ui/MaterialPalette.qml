import QtQuick
import "MaterialColors.generated.js" as Colors

// Qt-only palette; desktop integration belongs to Theme, not the color engine.
QtObject {
    property color seedColor: "#6750a4"
    property bool dark: false
    readonly property var roles: Colors.MaterialColors.createScheme(seedColor.r, seedColor.g, seedColor.b, dark)

    readonly property color primary: roles.primary
    readonly property color onPrimary: roles.onPrimary
    readonly property color primaryContainer: roles.primaryContainer
    readonly property color onPrimaryContainer: roles.onPrimaryContainer
    readonly property color secondary: roles.secondary
    readonly property color onSecondary: roles.onSecondary
    readonly property color secondaryContainer: roles.secondaryContainer
    readonly property color onSecondaryContainer: roles.onSecondaryContainer
    readonly property color tertiary: roles.tertiary
    readonly property color onTertiary: roles.onTertiary
    readonly property color tertiaryContainer: roles.tertiaryContainer
    readonly property color onTertiaryContainer: roles.onTertiaryContainer
    readonly property color surface: roles.surface
    readonly property color surfaceContainerLowest: roles.surfaceContainerLowest
    readonly property color surfaceContainerLow: roles.surfaceContainerLow
    readonly property color surfaceContainer: roles.surfaceContainer
    readonly property color surfaceContainerHigh: roles.surfaceContainerHigh
    readonly property color surfaceContainerHighest: roles.surfaceContainerHighest
    readonly property color onSurface: roles.onSurface
    readonly property color onSurfaceVariant: roles.onSurfaceVariant
    readonly property color outline: roles.outline
    readonly property color outlineVariant: roles.outlineVariant
    readonly property color error: roles.error
    readonly property color onError: roles.onError
    readonly property color errorContainer: roles.errorContainer
    readonly property color onErrorContainer: roles.onErrorContainer
    readonly property color success: roles.success
    readonly property color onSuccess: roles.onSuccess
    readonly property color warning: roles.warning
    readonly property color onWarning: roles.onWarning
}
