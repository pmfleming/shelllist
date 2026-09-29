import QtQuick
import QtQuick.Layouts
import Shelllist.Core as Core

Column {
    id: header

    required property real uiScale
    property string icon: ""
    property url iconSource: ""
    property bool signalIcon: false
    property color iconColor: Theme.mutedText
    property color iconBorderColor: Theme.strongBorder
    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.mutedText
    property bool statusIndicatorVisible: false
    property color statusIndicatorColor: subtitleColor
    property int subtitleWeight: Theme.fontWeightRegular
    property int titlePixelSize: Math.round(Theme.fontSizeTitle * uiScale)
    property var actions: []
    property int actionWidth: 170
    readonly property var primaryActions: Core.Model.visibleActions(actions, "primary")
    readonly property var secondaryActions: Core.Model.visibleActions(actions, "toolbar")
    readonly property int primaryActionCount: primaryActions.length
    property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    property int controlHeight: Math.max(Theme.compactControlHeight, Math.round(Theme.controlHeight * uiScale))
    property bool secondaryVisible: true
    property bool stackedPrimary: false
    property bool inlineActions: false
    readonly property var inlineActionItems: primaryActions.concat(secondaryVisible ? secondaryActions : [])
    readonly property bool useInlineActions: inlineActions && !stackedPrimary && width >= 420 && inlineActionItems.length > 0 && inlineActionItems.length <= 3 && inlineActionItems.every(action => !!action.icon)
    readonly property bool hasStackedPrimary: stackedPrimary && primaryActionCount > 0
    property int sectionSpacing: Theme.verticalSpacing(Theme.spacingMd, uiScale)
    readonly property bool hasSecondaryActions: secondaryVisible && secondaryActions.length > 0
    readonly property int secondaryHeight: hasSecondaryActions && !useInlineActions ? controlHeight : 0

    signal actionTriggered(string actionId)

    spacing: secondaryHeight > 0 || hasStackedPrimary ? sectionSpacing : 0
    height: headerHeight + secondaryHeight + (hasStackedPrimary ? controlHeight : 0) + spacing * (Number(secondaryHeight > 0) + Number(hasStackedPrimary))

    RowLayout {
        width: parent.width
        height: header.headerHeight
        spacing: Math.max(Theme.spacingSm, Math.round(Theme.spacingMd * header.uiScale))

        IconTile {
            objectName: "detailIdentityIcon"
            Layout.preferredWidth: Math.round(58 * header.uiScale)
            Layout.preferredHeight: Math.round(54 * header.uiScale)
            Layout.alignment: Qt.AlignVCenter
            icon: header.signalIcon ? "" : header.icon
            iconSource: header.signalIcon ? "" : header.iconSource
            iconColor: header.iconColor
            iconSize: Math.max(Theme.iconSizeLarge, Math.round(Theme.iconSizeLarge * header.uiScale))
            backgroundColor: Theme.selected
            borderColor: header.iconBorderColor

            SignalIcon {
                visible: header.signalIcon
                anchors.centerIn: parent
                width: Math.round(48 * header.uiScale)
                height: Math.round(40 * header.uiScale)
                level: 3
                iconColor: header.iconColor
            }
        }

        ResultLabel {
            title: header.title
            subtitle: header.subtitle
            subtitleColor: header.subtitleColor
            statusIndicatorVisible: header.statusIndicatorVisible
            statusIndicatorColor: header.statusIndicatorColor
            titleWeight: Theme.fontWeightBold
            subtitleWeight: header.subtitleWeight
            titlePixelSize: header.titlePixelSize
            subtitlePixelSize: Math.max(Theme.fontSizeCaption, Math.round(Theme.fontSizeSmall * header.uiScale))
            uiScale: header.uiScale
        }

        ActionToolbar {
            visible: !header.stackedPrimary && (header.primaryActionCount > 0 || header.useInlineActions)
            Layout.preferredWidth: !visible ? 0 : header.useInlineActions ? header.inlineActionItems.length * header.controlHeight + (header.inlineActionItems.length - 1) * spacing : header.actionWidth
            Layout.preferredHeight: header.controlHeight
            actions: header.useInlineActions ? header.inlineActionItems : header.actions
            includeAllGroups: header.useInlineActions
            group: "primary"
            tabFocusEnabled: false
            shortcutOffset: 0
            controlHeight: header.controlHeight
            onTriggered: function (actionId) {
                header.actionTriggered(actionId);
            }
        }
    }

    ActionToolbar {
        visible: header.hasStackedPrimary
        width: parent.width
        height: header.controlHeight
        actions: header.actions
        group: "primary"
        tabFocusEnabled: false
        shortcutOffset: 0
        fillActions: true
        controlHeight: header.controlHeight
        onTriggered: function (actionId) {
            header.actionTriggered(actionId);
        }
    }

    ActionToolbar {
        visible: header.hasSecondaryActions && !header.useInlineActions
        width: parent.width
        height: header.secondaryHeight
        actions: header.actions
        group: "toolbar"
        tabFocusEnabled: false
        shortcutOffset: header.primaryActionCount
        alignRight: true
        fillActions: header.stackedPrimary
        controlHeight: header.controlHeight
        onTriggered: function (actionId) {
            header.actionTriggered(actionId);
        }
    }
}
