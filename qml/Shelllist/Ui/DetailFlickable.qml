import QtQuick

Flickable {
    id: page

    // Direct children are positioned by the Column. Give them width and
    // explicit/implicit height, not vertical anchors (including anchors.fill).
    // Anchor content inside an unanchored Item/DetailCard when it needs a slot.
    default property alias cards: cardColumn.data
    property int cardSpacing: Theme.verticalSpacing(Theme.spacingMd, Theme.densityScale(height, 0))
    property bool revealFocusedControl: false
    readonly property Item focusedControl: Window.window ? Window.window.activeFocusItem : null

    // Opt-in for form workspaces: keyboard focus must not disappear below the
    // viewport when a wide inspector stacks vertically on a small display.
    function revealFocus(): void {
        if (!revealFocusedControl || !focusedControl)
            return;
        let ancestor = focusedControl.parent;
        while (ancestor && ancestor !== contentItem)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        const position = focusedControl.mapToItem(contentItem, 0, 0);
        if (position.y < contentY)
            contentY = Math.max(0, position.y - Theme.spacingSm);
        else if (position.y + focusedControl.height > contentY + height)
            contentY = Math.max(0, Math.min(contentHeight - height, position.y + focusedControl.height - height + Theme.spacingSm));
    }
    onFocusedControlChanged: Qt.callLater(revealFocus)

    contentWidth: width
    contentHeight: cardColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    clip: true

    Column {
        id: cardColumn
        width: page.width
        spacing: page.cardSpacing
    }
}
