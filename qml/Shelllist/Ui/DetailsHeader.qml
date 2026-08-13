import QtQuick
import QtQuick.Layouts

Column {
    id: header

    required property real uiScale
    property string icon: ""
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
    property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    property int controlHeight: Math.max(Theme.compactControlHeight, Math.round(Theme.controlHeight * uiScale))
    property bool secondaryVisible: true
    property int sectionSpacing: Theme.verticalSpacing(Theme.spacingMd, uiScale)
    readonly property bool hasSecondaryActions: secondaryVisible && actions.some(function (action) {
        return action.visible !== false && (action.presentation || {}).group === "toolbar";
    })
    readonly property int secondaryHeight: hasSecondaryActions ? controlHeight : 0

    signal actionTriggered(string actionId)

    spacing: hasSecondaryActions ? sectionSpacing : 0
    height: headerHeight + secondaryHeight + spacing

    RowLayout {
        width: parent.width
        height: header.headerHeight
        spacing: Math.max(Theme.spacingSm, Math.round(Theme.spacingMd * header.uiScale))

        IconTile {
            Layout.preferredWidth: Math.round(58 * header.uiScale)
            Layout.preferredHeight: Math.round(54 * header.uiScale)
            Layout.alignment: Qt.AlignVCenter
            icon: header.signalIcon ? "" : header.icon
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
            visible: header.actions.length > 0
            Layout.preferredWidth: visible ? header.actionWidth : 0
            Layout.preferredHeight: header.controlHeight
            actions: header.actions
            group: "primary"
            controlHeight: header.controlHeight
            onTriggered: function (actionId) { header.actionTriggered(actionId); }
        }
    }

    ActionToolbar {
        visible: header.hasSecondaryActions
        width: parent.width
        height: header.secondaryHeight
        actions: header.actions
        group: "toolbar"
        alignRight: true
        controlHeight: header.controlHeight
        onTriggered: function (actionId) { header.actionTriggered(actionId); }
    }
}
