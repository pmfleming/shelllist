pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Core as Core

// Surface commands only. Settings and contextual content toolbars stay separate.
Item {
    id: row
    property var actions: []
    property real uiScale: 1
    property bool secondaryVisible: true
    readonly property var primaryActions: Core.Model.visibleActions(actions, "primary")
    readonly property var secondaryActions: secondaryVisible ? Core.Model.visibleActions(actions, "toolbar") : []
    readonly property var primaryAction: primaryActions.length ? primaryActions[0] : null
    readonly property int controlHeight: Math.round(Theme.secondaryActionHeight * uiScale)
    readonly property int gap: Math.round(Theme.spacingSm * uiScale)
    readonly property int preferredPrimaryWidth: primaryAction ? Math.min(Math.max(Theme.primaryActionMinWidth * uiScale, primaryButton.implicitWidth), Theme.primaryActionMaxWidth * uiScale) : 0
    readonly property int primaryWidth: Math.min(preferredPrimaryWidth, Math.max(0, width - (secondaryActions.length ? controlHeight + gap : 0)))
    readonly property int shownSecondaryCount: fittingSecondaryCount()
    readonly property var shownSecondary: secondaryActions.slice(0, shownSecondaryCount)
    readonly property var overflowActions: secondaryActions.slice(shownSecondaryCount)
    readonly property bool popupOpen: overflowMenu.visible
    // count can change before Repeater has instantiated its delegates. Track
    // actual additions/removals so navigation never caches an incomplete list.
    property list<ActionControl> secondaryButtons: []
    readonly property list<ActionControl> buttons: (primaryAction ? [primaryButton] : []).concat(Array.from(secondaryButtons), overflowActions.length ? [moreButton] : [])
    signal triggered(string actionId)
    implicitHeight: primaryAction || secondaryActions.length ? Math.round(Theme.primaryActionHeight * uiScale) : 0
    height: implicitHeight

    FontMetrics {
        id: labelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(Theme.fontSizeBody * row.uiScale)
    }
    function secondaryWidth(action): real {
        return action.icon ? controlHeight : Math.ceil(Math.min(Theme.secondaryActionMaxWidth * uiScale, Math.max(controlHeight, labelMetrics.advanceWidth(action.label || "") + Theme.actionHorizontalPadding * 2 * uiScale)));
    }
    function actionTone(action, primary): string {
        const tone = (action.presentation || {}).tone || (action.role === "destructive" ? "danger" : "normal");
        return tone === "danger" || tone === "warning" ? tone : primary ? "accent" : "normal";
    }
    function fittingSecondaryCount(): int {
        let used = preferredPrimaryWidth;
        for (let i = 0; i < secondaryActions.length; ++i) {
            const next = used + (used ? gap : 0) + secondaryWidth(secondaryActions[i]);
            const reserve = i < secondaryActions.length - 1 ? gap + controlHeight : 0;
            if (next + reserve > width) return i;
            used = next;
        }
        return secondaryActions.length;
    }
    function keyFor(action): string {
        const key = String(action.accessKey || "").trim().toUpperCase();
        return /^[A-Z]$/.test(key) && key !== "S" && key !== "M" && key !== "J" ? key : "";
    }
    function closePopup(): void { overflowMenu.close(); }
    onVisibleChanged: if (!visible) closePopup()
    onEnabledChanged: if (!enabled) closePopup()
    onActionsChanged: closePopup()
    onWidthChanged: closePopup()

    Row {
        id: actionLine
        height: row.height
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: row.gap
        ActionButton {
            id: primaryButton
            objectName: "detailAction:" + (row.primaryAction ? row.primaryAction.id : "")
            visible: !!row.primaryAction
            width: row.primaryWidth
            height: implicitHeight
            sizeRole: "primary"
            uiScale: row.uiScale
            iconSize: Math.round(Theme.iconSizeSmall * uiScale)
            anchors.verticalCenter: parent.verticalCenter
            activeFocusOnTab: false
            label: row.primaryAction ? row.primaryAction.label : ""
            icon: row.primaryAction ? row.primaryAction.icon || "" : ""
            iconOnly: false
            accessKey: row.primaryAction ? row.keyFor(row.primaryAction) : ""
            toolTip: row.primaryAction ? (row.primaryAction.metadata || {}).toolTip || "" : ""
            enabled: !!row.primaryAction && row.primaryAction.enabled !== false
            tone: row.primaryAction ? row.actionTone(row.primaryAction, true) : "normal"
            onClicked: row.triggered(row.primaryAction.id)
        }
        Repeater {
            model: row.shownSecondary
            onItemAdded: function(index, item) {
                const buttons = row.secondaryButtons.slice();
                buttons.splice(index, 0, item);
                row.secondaryButtons = buttons;
            }
            onItemRemoved: function(index, item) {
                row.secondaryButtons = row.secondaryButtons.filter(button => button !== item);
            }
            delegate: ActionButton {
                required property var modelData
                objectName: "detailAction:" + modelData.id
                width: row.secondaryWidth(modelData)
                height: row.controlHeight
                sizeRole: "secondary"
                uiScale: row.uiScale
                iconSize: Math.round(Theme.iconSizeSmall * uiScale)
                anchors.verticalCenter: actionLine.verticalCenter
                activeFocusOnTab: false
                label: modelData.label || ""
                icon: modelData.icon || ""
                accessKey: row.keyFor(modelData)
                toolTip: (modelData.metadata || {}).toolTip || ""
                enabled: modelData.enabled !== false
                tone: row.actionTone(modelData, false)
                onClicked: row.triggered(modelData.id)
            }
        }
        ActionButton {
            id: moreButton
            objectName: "surfaceActionMore"
            visible: row.overflowActions.length > 0
            width: row.controlHeight
            height: row.controlHeight
            anchors.verticalCenter: parent.verticalCenter
            activeFocusOnTab: false
            accessKey: "M"
            label: qsTr("More actions")
            sizeRole: "secondary"
            uiScale: row.uiScale
            icon: "more_horiz"
            onClicked: overflowMenu.open()
            // Popup rather than Menu: native Menu treats Alt as dismissal and
            // can expose the underlying header shortcut in the same chord.
            ActionMenu {
                id: overflowMenu
                y: moreButton.height
                x: moreButton.width - width
                width: Math.min(row.width, Math.max(220 * row.uiScale, row.controlHeight))
                controlHeight: row.controlHeight
                listObjectName: "surfaceActionMenu"
                actions: row.overflowActions
                onTriggered: function (action) { row.triggered(action.id); }
            }
        }
    }
}
