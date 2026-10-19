import QtQuick

Item {
    id: clock

    property bool active: false
    property int updateInterval: 60000
    property bool alignToMinute: false
    property date now
    property bool initialized: false

    width: 0
    height: 0
    visible: false

    function refresh(): void {
        now = new Date();
        if (initialized && active) {
            // Recompute from wall time after every tick so late delivery does
            // not accumulate drift. Only one timer runs while the view is active.
            tick.interval = alignToMinute ? 60000 - now.getTime() % 60000 : Math.max(1, updateInterval);
            tick.restart();
        }
    }

    onActiveChanged: {
        if (active)
            refresh();
        else if (initialized)
            tick.stop();
    }
    onUpdateIntervalChanged: if (initialized && active)
        refresh()
    onAlignToMinuteChanged: if (initialized && active)
        refresh()
    Component.onCompleted: {
        initialized = true;
        refresh();
    }

    Timer {
        id: tick
        repeat: false
        onTriggered: clock.refresh()
    }
}
