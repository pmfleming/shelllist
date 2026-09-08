import QtQuick

DetailsPane {
    id: pane

    required property real uiScale
    property alias icon: header.icon
    property alias signalIcon: header.signalIcon
    property alias iconColor: header.iconColor
    property alias iconBorderColor: header.iconBorderColor
    property alias title: header.title
    property alias subtitle: header.subtitle
    property alias subtitleColor: header.subtitleColor
    property alias statusIndicatorVisible: header.statusIndicatorVisible
    property alias statusIndicatorColor: header.statusIndicatorColor
    property alias subtitleWeight: header.subtitleWeight
    property alias titlePixelSize: header.titlePixelSize
    property alias actions: header.actions
    property alias actionWidth: header.actionWidth
    property alias headerHeight: header.headerHeight
    property alias controlHeight: header.controlHeight
    property alias secondaryVisible: header.secondaryVisible
    readonly property real bodyHeight: body.height
    default property alias bodyContent: body.data

    signal actionTriggered(string actionId)

    densityScale: uiScale

    DetailsHeader {
        id: header
        width: parent.width
        uiScale: pane.uiScale
        sectionSpacing: pane.sectionSpacing
        onActionTriggered: function (actionId) { pane.actionTriggered(actionId); }
    }

    Item {
        id: body
        width: parent.width
        height: Math.max(0, parent.height - header.height - pane.sectionSpacing)
    }
}
