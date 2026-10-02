import QtQuick
import QtQuick.Layouts

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
    // Transitional aliases for consumers migrated in the surface rollout.
    property int actionWidth: 170
    property int controlHeight: Theme.controlHeight
    property bool stackedPrimary: false
    property bool inlineActions: false
    property bool secondaryVisible: true
    property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    property int sectionSpacing: Theme.verticalSpacing(Theme.spacingMd, uiScale)
    signal actionTriggered(string actionId)
    spacing: actionRow.height > 0 ? sectionSpacing : 0
    height: headerHeight + actionRow.height + spacing

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
    }
    SurfaceActionRow {
        id: actionRow
        objectName: "surfaceActionRow"
        width: parent.width
        uiScale: header.uiScale
        actions: header.actions
        secondaryVisible: header.secondaryVisible
        onTriggered: function(actionId) { header.actionTriggered(actionId); }
    }
}
