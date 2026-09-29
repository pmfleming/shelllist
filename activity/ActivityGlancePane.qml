pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: pane

    required property ActivityController controller
    required property date now

    GlanceScheduleCard {
        objectName: "activityScheduleSummary"
        width: pane.width
        height: Math.max(250, Math.min(320, pane.height * 0.38))
        controller: pane.controller
        now: pane.now
    }

}
