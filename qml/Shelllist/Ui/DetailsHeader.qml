import QtQuick
import QtQuick.Layouts

Item {
    id: header
    required property real uiScale
    property string icon: ""
    property url iconSource: ""
    property int iconCount: 1
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
    property bool secondaryVisible: true
    property bool compactSecondaryActions: false
    property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    signal actionTriggered(string actionId)
    property bool tabFocusEnabled: false
    function focusAction(actionId: string): void { actionRow.focusAction(actionId); }
    implicitHeight: actionRow.implicitHeight
    height: implicitHeight

    RowLayout {
        width: Math.max(0, parent.width - actionRow.primaryWidth - (actionRow.primaryWidth ? Theme.actionTitleGap * header.uiScale : 0))
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
            GroupCountBadge {
                count: header.iconCount
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }
            SignalIcon {
                visible: header.signalIcon
                anchors.centerIn: parent
                width: Math.round(48 * header.uiScale)
                height: Math.round(40 * header.uiScale)
                level: 3
                iconColor: header.iconColor
            }
        }
        Item {
            objectName: "detailIdentityLabel"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            ThemeText {
                id: titleText
                objectName: "detailTitle"
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                text: header.title
                font.weight: Theme.fontWeightBold
                font.pixelSize: header.titlePixelSize
                elide: Text.ElideRight
            }
            RowLayout {
                anchors.top: titleText.bottom
                anchors.topMargin: Math.round(2 * header.uiScale)
                width: parent.width
                visible: header.subtitle.length > 0 || header.statusIndicatorVisible
                spacing: Theme.spacingSm * header.uiScale
                Rectangle {
                    visible: header.statusIndicatorVisible
                    Layout.preferredWidth: 8 * header.uiScale
                    Layout.preferredHeight: 8 * header.uiScale
                    radius: width / 2
                    color: header.statusIndicatorColor
                }
                ThemeText {
                    objectName: "detailSubtitle"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: header.subtitle
                    color: header.subtitleColor
                    font.weight: header.subtitleWeight
                    font.pixelSize: Math.max(Theme.fontSizeCaption, Math.round(Theme.fontSizeSmall * header.uiScale))
                    elide: Text.ElideRight
                }
            }
        }
    }
    SurfaceActionRow {
        id: actionRow
        objectName: "surfaceActionRow"
        width: parent.width
        uiScale: header.uiScale
        identityHeight: header.headerHeight
        reserveIdentity: true
        tabFocusEnabled: header.tabFocusEnabled
        actions: header.actions
        secondaryVisible: header.secondaryVisible
        compactSecondaryActions: header.compactSecondaryActions
        onTriggered: function(actionId) { header.actionTriggered(actionId); }
    }
}
