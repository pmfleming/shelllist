pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Core as Core

// One command owner for both header tiers. Identity is laid out beside the
// primary by DetailsHeader; secondaries fit independently on the lower tier.
Item {
    id: row
    property var actions: []
    property real uiScale: 1
    property bool secondaryVisible: true
    property real identityHeight: Math.round(Theme.primaryActionHeight * uiScale)
    property bool reserveIdentity: false
    property bool tabFocusEnabled: false
    readonly property var primaryActions: Core.Model.visibleActions(actions, "primary")
    readonly property var secondaryActions: secondaryVisible ? Core.Model.visibleActions(actions, "toolbar") : []
    readonly property var primaryAction: primaryActions.length ? primaryActions[0] : null
    readonly property int controlHeight: Math.round(Theme.secondaryActionHeight * uiScale)
    readonly property int gap: Math.round(Theme.spacingSm * uiScale)
    readonly property int primaryWidth: primaryAction ? Math.round(Theme.primaryActionHeight * uiScale) : 0
    readonly property real topHeight: primaryAction || reserveIdentity ? Math.max(identityHeight, primaryWidth) : 0
    readonly property int shownSecondaryCount: fittingSecondaryCount()
    readonly property var shownSecondary: secondaryActions.slice(0, shownSecondaryCount)
    readonly property var overflowActions: secondaryActions.slice(shownSecondaryCount)
    readonly property bool popupOpen: overflowMenu.visible
    // Repeater.count may change before delegates exist. Track actual lifetime
    // so command discovery never caches missing or destroyed buttons.
    property list<ActionControl> secondaryButtons: []
    readonly property list<ActionControl> buttons: (primaryAction ? [primaryButton] : []).concat(Array.from(secondaryButtons), overflowActions.length ? [moreButton] : [])
    signal triggered(string actionId)
    implicitHeight: topHeight + (secondaryActions.length ? (topHeight ? gap : 0) + controlHeight : 0)
    height: implicitHeight

    function actionTone(action, primary): string {
        const tone = (action.presentation || {}).tone || (action.role === "destructive" ? "danger" : "normal");
        return tone === "danger" || tone === "warning" ? tone : primary ? "accent" : "normal";
    }
    function fittingSecondaryCount(): int {
        const slots = Math.max(1, Math.floor((width + gap) / (controlHeight + gap)));
        return secondaryActions.length <= slots ? secondaryActions.length : slots - 1;
    }
    function keyFor(action): string {
        const key = String(action.accessKey || "").trim().toUpperCase();
        return /^[A-Z]$/.test(key) && key !== "S" && key !== "M" && key !== "J" ? key : "";
    }
    function focusAction(actionId: string): void {
        const button = buttons.find(item => item.objectName === "detailAction:" + actionId);
        if (button && button.enabled) button.forceActiveFocus();
    }
    function closePopup(): void { overflowMenu.close(); }
    onVisibleChanged: if (!visible) closePopup()
    onEnabledChanged: if (!enabled) closePopup()
    onActionsChanged: closePopup()
    onWidthChanged: closePopup()

    ActionButton {
        id: primaryButton
        objectName: "detailAction:" + (row.primaryAction ? row.primaryAction.id : "")
        visible: !!row.primaryAction
        anchors.right: parent.right
        y: (row.topHeight - height) / 2
        sizeRole: "primary"
        uiScale: row.uiScale
        activeFocusOnTab: row.tabFocusEnabled && enabled
        label: row.primaryAction ? row.primaryAction.label : ""
        icon: row.primaryAction ? row.primaryAction.icon || "play_arrow" : ""
        accessKey: row.primaryAction ? row.keyFor(row.primaryAction) : ""
        toolTip: row.primaryAction ? (row.primaryAction.metadata || {}).toolTip || "" : ""
        enabled: !!row.primaryAction && row.primaryAction.enabled !== false
        tone: row.primaryAction ? row.actionTone(row.primaryAction, true) : "normal"
        onClicked: row.triggered(row.primaryAction.id)
    }
    Row {
        id: actionLine
        anchors.right: parent.right
        y: row.topHeight + (row.topHeight ? row.gap : 0)
        spacing: row.gap
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
                sizeRole: "secondary"
                uiScale: row.uiScale
                activeFocusOnTab: row.tabFocusEnabled && enabled
                label: modelData.label || ""
                icon: modelData.icon || "more_horiz"
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
            activeFocusOnTab: row.tabFocusEnabled && enabled
            accessKey: "M"
            label: qsTr("More actions")
            sizeRole: "secondary"
            uiScale: row.uiScale
            icon: "more_horiz"
            onClicked: overflowMenu.open()
            // Shared modal Popup, not a native Menu that dismisses itself on
            // Alt and can expose the underlying command in the same chord.
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
