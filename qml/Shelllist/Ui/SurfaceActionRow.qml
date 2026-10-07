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
    property bool compactSecondaryActions: false
    readonly property real secondaryUiScale: controlHeight / Theme.secondaryActionHeight
    property real identityHeight: Math.round(Theme.primaryActionHeight * uiScale)
    property bool reserveIdentity: false
    property bool tabFocusEnabled: false
    readonly property var primaryActions: Core.Model.visibleActions(actions, "primary")
    readonly property var secondaryActions: secondaryVisible ? Core.Model.visibleActions(actions, "toolbar") : []
    readonly property var menuActions: secondaryVisible ? Core.Model.visibleActions(actions, "overflow") : []
    readonly property var primaryAction: primaryActions.length ? primaryActions[0] : null
    readonly property int nominalControlHeight: Math.round(Theme.secondaryActionHeight * uiScale * (compactSecondaryActions ? Theme.expandedSecondaryActionScale : 1))
    readonly property int minimumControlHeight: Math.round(Theme.minimumSecondaryActionHeight * uiScale)
    readonly property int gap: Math.round(Theme.spacingSm * uiScale)
    readonly property int minimumGap: Math.round(Theme.minimumActionGap * uiScale)
    readonly property int requestedSlots: secondaryActions.length + (menuActions.length ? 1 : 0)
    // Exhaust spacing before shrinking circles; only then omit disabled commands.
    readonly property int secondaryGap: requestedSlots > 1 ? Math.max(minimumGap, Math.min(gap, Math.floor((width - requestedSlots * nominalControlHeight) / (requestedSlots - 1)))) : gap
    readonly property int controlHeight: requestedSlots ? Math.max(minimumControlHeight, Math.min(nominalControlHeight, Math.floor((width - (requestedSlots - 1) * secondaryGap) / requestedSlots))) : nominalControlHeight
    readonly property int primaryWidth: primaryAction ? Math.round(Theme.primaryActionHeight * uiScale) : 0
    readonly property real topHeight: primaryAction || reserveIdentity ? Math.max(identityHeight, primaryWidth) : 0
    readonly property var shownSecondary: fittingSecondaryActions()
    readonly property int shownSecondaryCount: shownSecondary.length
    // Only explicitly named menu commands belong in More, never width overflow.
    readonly property var overflowActions: menuActions
    readonly property int visibleSlots: shownSecondaryCount + (menuActions.length ? 1 : 0)
    readonly property int columns: Math.max(1, Math.floor((width + secondaryGap) / (controlHeight + secondaryGap)))
    readonly property int secondaryRows: Math.ceil(visibleSlots / columns)
    readonly property real secondaryHeight: secondaryRows ? secondaryRows * controlHeight + (secondaryRows - 1) * secondaryGap : 0
    readonly property bool popupOpen: overflowMenu.visible
    // Repeater.count may change before delegates exist. Track actual lifetime
    // so command discovery never caches missing or destroyed buttons.
    property list<ActionControl> secondaryButtons: []
    readonly property list<ActionControl> buttons: (primaryAction ? [primaryButton] : []).concat(Array.from(secondaryButtons), overflowActions.length ? [moreButton] : [])
    signal triggered(string actionId)
    implicitHeight: topHeight + (visibleSlots ? (topHeight ? gap : 0) + secondaryHeight : 0)
    height: implicitHeight

    function actionTone(action, primary): string {
        const tone = (action.presentation || {}).tone || (action.role === "destructive" ? "danger" : "normal");
        return tone === "danger" || tone === "warning" ? tone : primary ? "accent" : "normal";
    }
    function fittingSecondaryActions(): var {
        const slots = Math.max(0, Math.floor((width + minimumGap) / (minimumControlHeight + minimumGap)));
        if (requestedSlots <= slots)
            return secondaryActions;
        const enabledCount = secondaryActions.filter(action => action.enabled !== false).length;
        let disabledSlots = Math.max(0, slots - enabledCount - (menuActions.length ? 1 : 0));
        return secondaryActions.filter(action => action.enabled !== false || disabledSlots-- > 0);
    }
    // Pathological widths wrap enabled commands instead of hiding them or
    // shrinking below the shared minimum. Every line remains right-aligned.
    function secondaryX(index: int): real {
        const lineCount = Math.min(columns, visibleSlots - Math.floor(index / columns) * columns);
        return Math.max(0, width - lineCount * controlHeight - (lineCount - 1) * secondaryGap) + (index % columns) * (controlHeight + secondaryGap);
    }
    function secondaryY(index: int): real {
        return Math.floor(index / columns) * (controlHeight + secondaryGap);
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
    Item {
        width: parent.width
        height: row.secondaryHeight
        y: row.topHeight + (row.topHeight ? row.gap : 0)
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
                required property int index
                x: row.secondaryX(index)
                y: row.secondaryY(index)
                objectName: "detailAction:" + modelData.id
                sizeRole: "secondary"
                uiScale: row.secondaryUiScale
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
            x: row.secondaryX(row.shownSecondaryCount)
            y: row.secondaryY(row.shownSecondaryCount)
            visible: row.overflowActions.length > 0
            activeFocusOnTab: row.tabFocusEnabled && enabled
            accessKey: "M"
            label: qsTr("More actions")
            sizeRole: "secondary"
            uiScale: row.secondaryUiScale
            icon: "more_horiz"
            onClicked: overflowMenu.open()
            // Shared modal Popup, not a native Menu that dismisses itself on
            // Alt and can expose the underlying command in the same chord.
            ActionMenu {
                id: overflowMenu
                y: moreButton.height
                x: moreButton.width - width
                width: Math.min(row.width, Math.max(220 * row.uiScale, row.controlHeight))
                // Only circular header buttons shrink; named menu rows do not.
                controlHeight: Math.round(Theme.secondaryActionHeight * row.uiScale)
                listObjectName: "surfaceActionMenu"
                actions: row.overflowActions
                onTriggered: function (action) { row.triggered(action.id); }
            }
        }
    }
}
