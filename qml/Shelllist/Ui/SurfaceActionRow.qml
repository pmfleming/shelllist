pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
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
    readonly property int primaryWidth: primaryAction ? Math.min(Math.max(Theme.primaryActionMinWidth * uiScale, primaryButton.implicitWidth), Theme.primaryActionMaxWidth * uiScale, Math.max(0, width - (secondaryActions.length ? controlHeight + gap : 0))) : 0
    readonly property int shownSecondaryCount: fittingSecondaryCount()
    readonly property var shownSecondary: secondaryActions.slice(0, shownSecondaryCount)
    readonly property var overflowActions: secondaryActions.slice(shownSecondaryCount)
    readonly property bool popupOpen: overflowMenu.visible
    readonly property var buttons: {
        let result = primaryAction ? [primaryButton] : [];
        for (let i = 0; i < secondaryRepeater.count; ++i) {
            const button = secondaryRepeater.itemAt(i);
            if (button) result.push(button);
        }
        if (overflowActions.length) result.push(moreButton);
        return result;
    }
    signal triggered(string actionId)
    implicitHeight: primaryAction ? Math.round(Theme.primaryActionHeight * uiScale) : secondaryActions.length ? controlHeight : 0
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
        let used = primaryWidth;
        for (let i = 0; i < secondaryActions.length; ++i) {
            const next = used + (used ? gap : 0) + secondaryWidth(secondaryActions[i]);
            const reserve = i < secondaryActions.length - 1 ? gap + controlHeight : 0;
            if (next + reserve > width) return i;
            used = next;
        }
        return secondaryActions.length;
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
            enabled: !!row.primaryAction && row.primaryAction.enabled !== false
            tone: row.primaryAction ? row.actionTone(row.primaryAction, true) : "normal"
            onClicked: row.triggered(row.primaryAction.id)
        }
        Repeater {
            id: secondaryRepeater
            model: row.shownSecondary
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
            label: qsTr("More actions")
            sizeRole: "secondary"
            uiScale: row.uiScale
            icon: "more_horiz"
            onClicked: overflowMenu.open()
            Controls.Menu {
                id: overflowMenu
                y: moreButton.height
                modal: true
                onClosed: {
                    if (savedFocus && savedFocus.visible && savedFocus.enabled)
                        savedFocus.forceActiveFocus(Qt.OtherFocusReason);
                }
                property Item savedFocus: null
                onAboutToShow: savedFocus = row.Window.window ? row.Window.window.activeFocusItem : null
                Instantiator {
                    model: row.overflowActions
                    delegate: Controls.MenuItem {
                        required property var modelData
                        text: modelData.label || ""
                        enabled: modelData.enabled !== false
                        onTriggered: row.triggered(modelData.id)
                    }
                    onObjectAdded: function(index, object) { overflowMenu.insertItem(index, object); }
                    onObjectRemoved: function(index, object) { overflowMenu.removeItem(object); }
                }
            }
        }
    }
}
