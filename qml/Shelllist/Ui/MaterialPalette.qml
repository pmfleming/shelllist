import QtQuick
import "MaterialColors.generated.js" as Colors

// Qt-only palette; desktop integration belongs to Theme, not the color engine.
QtObject {
    property color seedColor: "#6750a4"
    property bool dark: false
    readonly property var roles: Colors.MaterialColors.createScheme(seedColor.r, seedColor.g, seedColor.b, dark)

    readonly property color primary: roles.primary
    // Avoid onX property names: Qt interprets their initializers as handlers.
    readonly property color primaryText: roles.onPrimary
    readonly property color primaryContainer: roles.primaryContainer
    readonly property color primaryContainerText: roles.onPrimaryContainer
    readonly property color secondary: roles.secondary
    readonly property color secondaryText: roles.onSecondary
    readonly property color secondaryContainer: roles.secondaryContainer
    readonly property color secondaryContainerText: roles.onSecondaryContainer
    readonly property color tertiary: roles.tertiary
    readonly property color tertiaryText: roles.onTertiary
    readonly property color tertiaryContainer: roles.tertiaryContainer
    readonly property color tertiaryContainerText: roles.onTertiaryContainer
    readonly property color surface: roles.surface
    readonly property color surfaceContainerLowest: roles.surfaceContainerLowest
    readonly property color surfaceContainerLow: roles.surfaceContainerLow
    readonly property color surfaceContainer: roles.surfaceContainer
    readonly property color surfaceContainerHigh: roles.surfaceContainerHigh
    readonly property color surfaceContainerHighest: roles.surfaceContainerHighest
    readonly property color surfaceText: roles.onSurface
    readonly property color surfaceVariantText: roles.onSurfaceVariant
    readonly property color outline: roles.outline
    readonly property color outlineVariant: roles.outlineVariant
    readonly property color error: roles.error
    readonly property color errorText: roles.onError
    readonly property color errorContainer: roles.errorContainer
    readonly property color errorContainerText: roles.onErrorContainer
    readonly property color success: roles.success
    readonly property color successText: roles.onSuccess
    readonly property color warning: roles.warning
    readonly property color warningText: roles.onWarning
}
