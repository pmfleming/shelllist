pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Ui.PanelSurface {
    id: grid
    required property AgendaCalendarController controller
    chooserController: controller
    property bool inputBlocked: false
    focusOnActivation: !controller.dayVisible || controller.focusRegion === "calendar"
    readonly property alias monthView: months
    readonly property alias dateNavigation: dates
    readonly property real cellHeight: 44 // Agenda owner: readable calendar hit geometry.
    readonly property real monthHeight: 6 * cellHeight + Ui.Theme.spacingXl * 3
    property bool restoring: true
    scopedNavigation: dates
    navigationEnabled: visible && detailsNavigation.activeFocus
    readonly property bool blocked: controller.navigationBlocked || inputBlocked || detailsNavigation.commandMenuOpen
    clip: true

    function restoreViewport(): void {
        restoring = true;
        months.forceLayout();
        months.contentY = controller.viewportOffset;
        restoring = false;
    }
    function reveal(key: string): void {
        const month = controller.monthFor(key);
        if (month < controller.windowStart || month >= controller.windowStart + controller.monthCount) {
            controller.windowStart = month - 4;
            controller.viewportOffset = 4 * monthHeight;
        } else controller.viewportOffset = (month - controller.windowStart) * monthHeight;
        restoreViewport();
    }
    function anchor(): void {
        if (restoring || months.contentY < 0 || months.contentHeight <= months.height) return;
        const top = Math.floor(months.contentY / monthHeight);
        const offset = months.contentY - top * monthHeight;
        controller.viewportOffset = months.contentY;
        if (top <= 1 || top >= controller.monthCount - 3) {
            restoring = true;
            controller.windowStart += top - 4;
            controller.viewportOffset = 4 * monthHeight + offset;
            months.contentY = controller.viewportOffset;
            restoring = false;
        }
    }
    Component.onCompleted: {
        controller.monthHeight = monthHeight;
        Qt.callLater(restoreViewport);
    }
    onVisibleChanged: if (visible) Qt.callLater(restoreViewport)
    Connections {
        target: grid.controller
        function onUiActiveChanged(): void { if (grid.controller.uiActive) Qt.callLater(grid.restoreViewport); }
        function onRevealDateRequested(key: string): void { grid.reveal(key); }
        function onCalendarFocusRequested(): void { if (grid.visible) dates.focusContent(); }
    }
    Ui.SurfaceActionRow {
        id: actions
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: grid.controller.contentMargin
        actions: [
            {id: "previous", label: qsTr("Previous month"), icon: "chevron_left", accessKey: "P", enabled: !grid.blocked, presentation: {group: "toolbar"}},
            {id: "today", label: qsTr("Today"), icon: "today", accessKey: "T", enabled: !grid.blocked, presentation: {group: "toolbar"}},
            {id: "next", label: qsTr("Next month"), icon: "chevron_right", accessKey: "N", enabled: !grid.blocked, presentation: {group: "toolbar"}}
        ]
        onTriggered: function(id) {
            if (id === "today") grid.controller.goToday();
            else grid.controller.moveMonth(id === "previous" ? -1 : 1);
            dates.focusContent();
        }
    }
    Ui.DateGridNavigation {
        id: dates
        anchors.top: actions.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: grid.controller.contentMargin
        dateKey: grid.controller.focusedDate
        blocked: grid.blocked
        onMoved: function(key) {
            grid.controller.navigationInteracted();
            grid.controller.focusedDate = key;
            const month = grid.controller.monthFor(key);
            const y = (month - grid.controller.windowStart) * grid.monthHeight;
            if (y < months.contentY || y + grid.monthHeight > months.contentY + months.height) grid.reveal(key);
        }
        onChosen: function(key) { grid.controller.chooseDay(key); }
        ListView {
            id: months
            objectName: "agendaCalendarMonths"
            anchors.fill: parent
            clip: true
            model: grid.controller.monthCount
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: !grid.blocked
            cacheBuffer: grid.monthHeight
            onContentYChanged: grid.anchor()
            delegate: Item {
                id: month
                required property int index
                readonly property int number: grid.controller.windowStart + index
                readonly property date first: new Date(Math.floor(number / 12), number % 12, 1, 12)
                readonly property int leading: (first.getDay() + 6) % 7
                readonly property int days: new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
                width: months.width
                height: grid.monthHeight
                Text {
                    width: parent.width
                    height: Ui.Theme.spacingXl
                    text: Qt.formatDate(month.first, "MMMM yyyy")
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.groupHeadingSize
                    font.weight: Font.Medium
                    Accessible.role: Accessible.Heading
                }
                Row {
                    y: Ui.Theme.spacingXl
                    width: parent.width
                    height: Ui.Theme.spacingXl
                    Repeater {
                        model: 7
                        Text {
                            required property int index
                            width: month.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().dayName(index + 1, Locale.ShortFormat)
                            color: Ui.Theme.mutedText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.metadataSize
                            Accessible.ignored: true
                        }
                    }
                }
                Grid {
                    y: Ui.Theme.spacingXl * 2
                    width: parent.width
                    columns: 7
                    Repeater {
                        model: 42
                        Rectangle {
                            id: cell
                            required property int index
                            readonly property int day: index - month.leading + 1
                            readonly property bool valid: day > 0 && day <= month.days
                            readonly property string key: valid ? grid.controller.monthKey(month.number).slice(0, 8) + day.toString().padStart(2, "0") : ""
                            readonly property var presence: grid.controller.markers[key] || ({event: false, task: false})
                            readonly property bool selected: key === grid.controller.selectedDate
                            width: month.width / 7
                            height: grid.cellHeight
                            radius: Ui.Theme.spacingSm
                            color: valid && selected ? Ui.Theme.selected : "transparent"
                            border.width: valid && key === grid.controller.today ? 1 : 0
                            border.color: Ui.Theme.accent
                            objectName: valid ? "calendarDate:" + key : ""
                            Accessible.role: Accessible.Button
                            Accessible.ignored: !valid
                            Accessible.name: valid ? Qt.formatDate(new Date(month.first.getFullYear(), month.first.getMonth(), day, 12), "dddd, d MMMM yyyy")
                                + (presence.event ? qsTr(", events present") : "") + (presence.task ? qsTr(", tasks present") : "") : ""
                            Accessible.selected: selected
                            Accessible.onPressAction: if (valid) dates.choose(key)
                            Text {
                                anchors.centerIn: parent
                                text: cell.valid ? cell.day : ""
                                color: Ui.Theme.text
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeLabel
                                Accessible.ignored: true
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Ui.Theme.spacingXs
                                spacing: Ui.Theme.spacingXs
                                Rectangle { width: 5; height: 5; radius: width / 2; color: Ui.Theme.accent; visible: cell.valid && cell.presence.event }
                                Rectangle { width: 5; height: 5; color: Ui.Theme.text; visible: cell.valid && cell.presence.task }
                            }
                            Ui.FocusRing {
                                anchors.fill: parent
                                active: cell.valid && dates.activeFocus && dates.dateKey === cell.key
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: cell.valid && !grid.blocked
                                onClicked: dates.choose(cell.key)
                            }
                        }
                    }
                }
            }
        }
    }
}
