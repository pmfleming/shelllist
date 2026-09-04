import QtQuick

Item {
    id: clock

    property bool active: false
    property int updateInterval: 60000
    property date now

    width: 0
    height: 0
    visible: false

    function refresh(): void { now = new Date(); }

    onActiveChanged: if (active) refresh()
    Component.onCompleted: refresh()

    Timer {
        interval: clock.updateInterval
        repeat: true
        running: clock.active
        onTriggered: clock.refresh()
    }
}
