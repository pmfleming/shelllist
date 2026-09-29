import QtQuick

Rectangle {
    id: frame

    property string title: ""
    property string detail: ""
    property real maximumCardWidth: 560
    readonly property bool compact: height < 720
    property real minimumOuterMargin: compact ? Theme.minimumVerticalSpacing : Theme.spacingLg
    property real cardPadding: Theme.spacingLg
    property real verticalCardPadding: compact ? Theme.minimumVerticalSpacing : Theme.spacingLg
    property real bodySpacing: compact ? Theme.minimumVerticalSpacing : Theme.spacingMd
    default property alias body: bodyColumn.data
    property Item precedingFocus: null
    readonly property bool ownsKeyboardFocus: containsItem(Window.window ? Window.window.activeFocusItem : null)
    Accessible.role: Accessible.Dialog
    Accessible.name: title
    Accessible.description: detail

    function containsItem(item: Item): bool {
        while (item && item !== frame)
            item = item.parent;
        return item === frame;
    }
    function focusTargets(item: Item): var {
        if (!item.visible || !item.enabled)
            return [];
        // Native focus-chain enumeration can omit custom TextInputs and
        // scrolled-out controls. Never omit sensitive inputs from dialog Tab.
        if (item.activeFocusOnTab || item instanceof TextInput || item instanceof TextEdit)
            return [item];
        let targets = [];
        for (const child of item.children)
            targets = targets.concat(focusTargets(child));
        return targets;
    }
    function moveFocus(backwards: bool): void {
        const targets = focusTargets(bodyColumn);
        if (!targets.length)
            return;
        let current = Window.window ? Window.window.activeFocusItem : null;
        while (current && !targets.includes(current))
            current = current.parent;
        const index = targets.indexOf(current);
        const next = index < 0 ? (backwards ? targets.length - 1 : 0) : (index + (backwards ? -1 : 1) + targets.length) % targets.length;
        targets[next].forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason);
    }
    onVisibleChanged: {
        if (visible) {
            viewport.contentY = 0;
            precedingFocus = Window.window ? Window.window.activeFocusItem : null;
        } else {
            if (precedingFocus && precedingFocus.visible && precedingFocus.enabled)
                precedingFocus.forceActiveFocus(Qt.OtherFocusReason);
            precedingFocus = null;
        }
    }

    Shortcut {
        sequence: "Tab"
        enabled: frame.visible && frame.ownsKeyboardFocus
        onActivated: frame.moveFocus(false)
    }
    Shortcut {
        sequence: "Shift+Tab"
        enabled: frame.visible && frame.ownsKeyboardFocus
        onActivated: frame.moveFocus(true)
    }

    anchors.fill: parent
    z: 10
    color: Theme.overlay

    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        width: Math.min(parent.width - 2 * frame.minimumOuterMargin, frame.maximumCardWidth)
        implicitHeight: contentColumn.implicitHeight + 2 * frame.verticalCardPadding
        height: Math.min(parent.height - 2 * frame.minimumOuterMargin, implicitHeight)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        radius: Theme.windowRadius
        color: Theme.surface
        border.color: Theme.strongBorder
        border.width: 1
        clip: true

        DetailFlickable {
            id: viewport
            objectName: "modalViewport"
            anchors.fill: parent
            anchors.leftMargin: frame.cardPadding
            anchors.rightMargin: frame.cardPadding
            anchors.topMargin: frame.verticalCardPadding
            anchors.bottomMargin: frame.verticalCardPadding
            revealFocusedControl: true
            cardSpacing: 0

            Column {
                id: contentColumn
                width: viewport.width
                spacing: frame.bodySpacing

                ThemeText {
                    width: parent.width
                    visible: frame.title.length > 0
                    text: frame.title
                    font.pixelSize: frame.compact ? Theme.fontSizeHeading : Theme.fontSizeDisplay
                    font.weight: Theme.fontWeightBold
                    wrapMode: Text.Wrap
                }

                ThemeText {
                    width: parent.width
                    visible: frame.detail.length > 0
                    text: frame.detail
                    color: Theme.mutedText
                    font.pixelSize: Theme.fontSizeLabel
                    wrapMode: Text.Wrap
                }

                Column {
                    id: bodyColumn

                    width: parent.width
                    spacing: frame.bodySpacing
                }
            }
        }
    }
}
