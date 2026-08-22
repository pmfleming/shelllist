import QtQuick

DetailsPane {
    id: pane

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
    property int controlHeight: Math.max(Theme.compactControlHeight,
        Math.round(Theme.controlHeight * uiScale))
    property bool secondaryVisible: true
    readonly property real bodyHeight: body.height
    default property alias bodyContent: body.data

    signal actionTriggered(string actionId)

    densityScale: uiScale

    DetailsHeader {
        id: header
        width: parent.width
        uiScale: pane.uiScale
        sectionSpacing: pane.sectionSpacing
        icon: pane.icon
        signalIcon: pane.signalIcon
        iconColor: pane.iconColor
        iconBorderColor: pane.iconBorderColor
        title: pane.title
        subtitle: pane.subtitle
        subtitleColor: pane.subtitleColor
        statusIndicatorVisible: pane.statusIndicatorVisible
        statusIndicatorColor: pane.statusIndicatorColor
        subtitleWeight: pane.subtitleWeight
        titlePixelSize: pane.titlePixelSize
        actions: pane.actions
        actionWidth: pane.actionWidth
        headerHeight: pane.headerHeight
        controlHeight: pane.controlHeight
        secondaryVisible: pane.secondaryVisible
        onActionTriggered: function (actionId) { pane.actionTriggered(actionId); }
    }

    Item {
        id: body
        width: parent.width
        height: Math.max(0, parent.height - header.height - pane.sectionSpacing)
    }
}
