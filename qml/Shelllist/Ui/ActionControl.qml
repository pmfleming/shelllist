import QtQuick

// Presentation-free activation shared by buttons, tabs, toggles and bar actions.
Rectangle {
    id: control

    property color focusRingColor: Theme.accent
    property Rectangle focusSurface: control
    property bool browseFocused: false
    // The top bar keeps tonal focus feedback without the panel browsing caret.
    property bool browseIndicatorVisible: true
    readonly property bool highlighted: activeFocus || browseFocused
    property string accessKey: ""
    // Repeated commands (e.g. field help) can share a letter in disjoint scopes.
    property Item commandScope: null
    readonly property DetailsNavigation shortcutNavigation: owningNavigation(parent)
    readonly property string surfaceShortcut: shortcutNavigation ? shortcutNavigation.shortcutFor(control) : ""
    function owningNavigation(item: Item): DetailsNavigation {
        while (item) {
            if (item instanceof DetailsNavigation) return item as DetailsNavigation;
            item = item.parent;
        }
        return null;
    }
    property string accessibleName: ""
    property bool interactive: true
    property bool keyboardPressed: false
    signal clicked

    color: "transparent"
    radius: Theme.controlRadius
    // Busy controls may keep focus, but must not activate until ready again.
    activeFocusOnTab: enabled && (interactive || activeFocus)
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: activate()

    function activate(): void {
        if (enabled && interactive)
            clicked();
    }

    FocusRing {
        parent: control.focusSurface
        active: control.highlighted
        browseIndicatorVisible: control.browseIndicatorVisible
        cornerRadius: control.focusSurface.radius
        ringColor: control.focusRingColor
    }

    onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
    onEnabledChanged: if (!enabled) keyboardPressed = false
    onInteractiveChanged: if (!interactive) keyboardPressed = false

    Keys.onReleased: function (event) {
        if (![Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
            return;
        if (!event.isAutoRepeat)
            keyboardPressed = false;
        event.accepted = true;
    }
    Keys.onPressed: function (event) {
        if (![Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
            return;
        if (!event.isAutoRepeat) {
            keyboardPressed = enabled && interactive;
            activate();
        }
        event.accepted = true;
    }
}
