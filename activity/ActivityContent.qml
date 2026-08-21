pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property ActivityController controller
    property date now: new Date()
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    function cellDate(index: int): date {
        const first = new Date(controller.viewDate.getFullYear(), controller.viewDate.getMonth(), 1);
        const mondayOffset = (first.getDay() + 6) % 7;
        return new Date(first.getFullYear(), first.getMonth(), index - mondayOffset + 1);
    }

    function eventTime(event: var): string {
        if (event.all_day)
            return "All day";
        return Qt.formatTime(new Date(event.start_unix_ms), "HH:mm") + "–"
            + Qt.formatTime(new Date(event.end_unix_ms), "HH:mm");
    }

    function worldTime(clock: var): string {
        const shifted = new Date(now.getTime() + Number(clock.utc_offset_seconds || 0) * 1000);
        return String(shifted.getUTCHours()).padStart(2, "0") + ":"
            + String(shifted.getUTCMinutes()).padStart(2, "0");
    }

    component HeaderButton: Rectangle {
        id: headerButton
        required property string label
        signal triggered
        width: Math.max(38, buttonText.implicitWidth + 18)
        height: 34
        radius: Ui.Theme.controlRadius
        color: pointer.containsMouse ? Ui.Theme.hover : Ui.Theme.controlBackground
        border.color: Ui.Theme.controlBorder
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: headerButton.label
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: headerButton.triggered()
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        Row {
            width: parent.width
            height: 42
            spacing: Ui.Theme.spacingSm

            Text {
                width: parent.width - headerActions.width - Ui.Theme.spacingSm
                anchors.verticalCenter: parent.verticalCenter
                text: "Activity"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
            }

            Row {
                id: headerActions
                height: parent.height
                spacing: Ui.Theme.spacingSm
                HeaderButton { label: "Today"; onTriggered: content.controller.goToToday() }
                HeaderButton { label: content.controller.activity.syncing ? "Syncing…" : "Refresh"; onTriggered: content.controller.refresh() }
            }
        }

        Rectangle {
            visible: content.controller.lastError.length > 0
            width: parent.width
            height: visible ? errorText.implicitHeight + 18 : 0
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.dangerBackground
            Text {
                id: errorText
                anchors.fill: parent
                anchors.margins: 9
                text: content.controller.lastError
                color: Ui.Theme.danger
                wrapMode: Text.Wrap
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }

        Row {
            width: parent.width
            height: parent.height - y
            spacing: Ui.Theme.spacingMd

            Rectangle {
                width: 360 * content.uiScale
                height: parent.height
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: Ui.Theme.spacingMd
                    spacing: Ui.Theme.spacingSm

                    Row {
                        width: parent.width
                        height: 36
                        HeaderButton { label: "‹"; onTriggered: content.controller.shiftMonth(-1) }
                        Text {
                            width: parent.width - 2 * 38
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatDate(content.controller.viewDate, "MMMM yyyy")
                            color: Ui.Theme.text
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeHeading
                            font.weight: Ui.Theme.fontWeightDemiBold
                        }
                        HeaderButton { label: "›"; onTriggered: content.controller.shiftMonth(1) }
                    }

                    Row {
                        width: parent.width
                        height: 22
                        Repeater {
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            Text {
                                required property string modelData
                                width: parent.width / 7
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        height: width * 6 / 7
                        columns: 7
                        rows: 6
                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                id: dayCell
                                required property int index
                                readonly property date value: content.cellDate(index)
                                readonly property bool selected: content.controller.dateKey(value)
                                    === content.controller.selectedDateKey
                                readonly property bool today: content.controller.dateKey(value)
                                    === content.controller.dateKey(content.now)
                                readonly property bool inMonth: value.getMonth()
                                    === content.controller.viewDate.getMonth()
                                width: parent.width / 7
                                height: parent.height / 6
                                radius: Ui.Theme.controlRadius
                                color: selected ? Ui.Theme.selected
                                    : dayPointer.containsMouse ? Ui.Theme.hover : "transparent"
                                border.color: today ? Ui.Theme.accent : "transparent"
                                border.width: today ? 1 : 0

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 7
                                    text: dayCell.value.getDate()
                                    color: dayCell.inMonth ? Ui.Theme.text : Ui.Theme.subtleText
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeBody
                                    font.weight: dayCell.selected || dayCell.today
                                        ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                                }
                                Rectangle {
                                    visible: content.controller.hasActivity(dayCell.value)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    width: 5
                                    height: 5
                                    radius: 3
                                    color: Ui.Theme.accent
                                }
                                MouseArea {
                                    id: dayPointer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: content.controller.selectDate(dayCell.value)
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: notificationPanel
                        width: parent.width
                        height: Math.max(120, parent.height - y)
                        radius: Ui.Theme.cardRadius
                        color: Ui.Theme.surfaceRaised
                        border.color: Ui.Theme.border

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: Ui.Theme.spacingSm

                            Row {
                                width: parent.width
                                height: 34
                                spacing: Ui.Theme.spacingSm
                                Text {
                                    width: parent.width - dndButton.width - clearButton.width
                                        - parent.spacing * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Notifications  " + (content.controller.notifications.count || 0)
                                    color: Ui.Theme.text
                                    elide: Text.ElideRight
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeLabel
                                    font.weight: Ui.Theme.fontWeightDemiBold
                                }
                                HeaderButton {
                                    id: dndButton
                                    label: content.controller.notifications.dnd ? "DND on" : "DND off"
                                    onTriggered: content.controller.toggleDnd()
                                }
                                HeaderButton {
                                    id: clearButton
                                    label: "Dismiss all"
                                    enabled: content.controller.notificationHistory.length > 0
                                    onTriggered: content.controller.clearNotifications()
                                }
                            }

                            Text {
                                visible: content.controller.notificationHistory.length === 0
                                width: parent.width
                                text: content.controller.notificationHistoryLoading
                                    ? "Loading history…" : "No notification history"
                                color: Ui.Theme.mutedText
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeSmall
                            }

                            ListView {
                                id: notificationHistoryList
                                width: parent.width
                                height: parent.height - y - historyFooter.height - parent.spacing
                                visible: content.controller.notificationHistory.length > 0
                                clip: true
                                spacing: Ui.Theme.spacingSm
                                model: content.controller.notificationHistory
                                delegate: NotificationHistoryRow {
                                    required property var modelData
                                    record: modelData
                                    controller: content.controller
                                }
                            }

                            Row {
                                id: historyFooter
                                width: parent.width
                                height: 32
                                spacing: Ui.Theme.spacingSm
                                HeaderButton {
                                    label: "Refresh"
                                    onTriggered: content.controller.reloadNotificationHistory()
                                }
                                HeaderButton {
                                    label: content.controller.notificationHistoryLoading
                                        ? "Loading…" : "Load more"
                                    enabled: content.controller.notificationHistoryHasMore
                                        && !content.controller.notificationHistoryLoading
                                    onTriggered: content.controller.loadMoreNotificationHistory()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width - x - rightPane.width - Ui.Theme.spacingMd
                height: parent.height
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: Ui.Theme.spacingMd
                    spacing: Ui.Theme.spacingSm
                    Text {
                        text: Qt.formatDate(content.controller.selectedDate, "dddd, d MMMM")
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeHeading
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Text {
                        visible: content.controller.selectedEvents.length === 0
                        text: content.controller.rangeLoading ? "Loading events…" : "No events"
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeBody
                    }
                    ListView {
                        width: parent.width
                        height: parent.height - y
                        spacing: Ui.Theme.spacingSm
                        clip: true
                        model: content.controller.selectedEvents
                        delegate: Rectangle {
                            id: eventRow
                            required property var modelData
                            width: ListView.view.width
                            height: Math.max(66, eventTitle.implicitHeight + 34)
                            radius: Ui.Theme.cardRadius
                            color: Ui.Theme.surfaceRaised
                            border.color: Ui.Theme.border
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 5
                                radius: 3
                                color: eventRow.modelData.color || Ui.Theme.accent
                            }
                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 10
                                anchors.topMargin: 9
                                anchors.bottomMargin: 9
                                spacing: 3
                                Text {
                                    id: eventTitle
                                    width: parent.width
                                    text: eventRow.modelData.title || "Untitled event"
                                    color: Ui.Theme.text
                                    elide: Text.ElideRight
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeLabel
                                    font.weight: Ui.Theme.fontWeightDemiBold
                                }
                                Text {
                                    width: parent.width
                                    text: content.eventTime(eventRow.modelData) + "  ·  "
                                        + (eventRow.modelData.calendar_name || "Calendar")
                                    color: Ui.Theme.mutedText
                                    elide: Text.ElideRight
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeSmall
                                }
                                Text {
                                    visible: (eventRow.modelData.location || "").length > 0
                                    width: parent.width
                                    text: eventRow.modelData.location || ""
                                    color: Ui.Theme.mutedText
                                    elide: Text.ElideRight
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightPane
                width: 300 * content.uiScale
                height: parent.height
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: Ui.Theme.spacingMd
                    spacing: Ui.Theme.spacingSm
                    Text {
                        text: "Todos"
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeHeading
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Row {
                        width: parent.width
                        height: 36
                        spacing: Ui.Theme.spacingSm
                        Rectangle {
                            width: parent.width - addTodo.width - parent.spacing
                            height: parent.height
                            radius: Ui.Theme.controlRadius
                            color: Ui.Theme.input
                            border.color: todoInput.activeFocus ? Ui.Theme.accent : Ui.Theme.border
                            TextInput {
                                id: todoInput
                                anchors.fill: parent
                                anchors.margins: 9
                                color: Ui.Theme.inputText
                                selectionColor: Ui.Theme.accent
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeBody
                                clip: true
                                onAccepted: {
                                    if (text.trim().length > 0 && content.controller.createTodo(text))
                                        text = "";
                                }
                            }
                            Text {
                                visible: todoInput.text.length === 0 && !todoInput.activeFocus
                                anchors.fill: parent
                                anchors.margins: 9
                                text: "Add for selected day"
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeBody
                            }
                        }
                        HeaderButton {
                            id: addTodo
                            label: "+"
                            onTriggered: {
                                if (todoInput.text.trim().length > 0
                                        && content.controller.createTodo(todoInput.text))
                                    todoInput.text = "";
                            }
                        }
                    }
                    ListView {
                        width: parent.width
                        height: Math.min(230 * content.uiScale, content.controller.selectedTodos.length * 46)
                        spacing: 5
                        clip: true
                        model: content.controller.selectedTodos
                        delegate: Rectangle {
                            id: todoRow
                            required property var modelData
                            width: ListView.view.width
                            height: 42
                            radius: Ui.Theme.controlRadius
                            color: Ui.Theme.surfaceRaised
                            border.color: Ui.Theme.border
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: deleteTodo.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: (todoRow.modelData.completed ? "✓  " : "○  ") + todoRow.modelData.title
                                color: todoRow.modelData.completed ? Ui.Theme.mutedText : Ui.Theme.text
                                font.strikeout: todoRow.modelData.completed
                                elide: Text.ElideRight
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeBody
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: content.controller.toggleTodo(todoRow.modelData)
                                }
                            }
                            Text {
                                id: deleteTodo
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                color: Ui.Theme.danger
                                font.pixelSize: 18
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: content.controller.deleteTodo(todoRow.modelData)
                                }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Ui.Theme.border }
                    Text {
                        text: "World clocks"
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeHeading
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Repeater {
                        model: content.controller.activity.world_clocks || []
                        delegate: Row {
                            id: worldClockRow
                            required property var modelData
                            width: parent.width
                            height: 30
                            Text {
                                width: parent.width - worldClockTime.width
                                text: worldClockRow.modelData.label || worldClockRow.modelData.city
                                color: Ui.Theme.text
                                elide: Text.ElideRight
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeBody
                            }
                            Text {
                                id: worldClockTime
                                text: content.worldTime(worldClockRow.modelData) + "  "
                                    + (worldClockRow.modelData.abbreviation || "")
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeBody
                            }
                        }
                    }
                    Text {
                        visible: (content.controller.activity.world_clocks || []).length === 0
                        text: "Add zones in bar-daemon activity.json"
                        color: Ui.Theme.mutedText
                        wrapMode: Text.Wrap
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                    }
                    Rectangle { width: parent.width; height: 1; color: Ui.Theme.border }
                    Text {
                        text: "Sources"
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeHeading
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Repeater {
                        model: content.controller.activity.sources || []
                        delegate: Row {
                            id: sourceRow
                            required property var modelData
                            width: parent.width
                            height: 26
                            spacing: 7
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 4
                                color: sourceRow.modelData.available
                                    ? Ui.Theme.active : Ui.Theme.danger
                            }
                            Text {
                                width: parent.width - 56
                                text: sourceRow.modelData.name || sourceRow.modelData.id
                                color: Ui.Theme.text
                                elide: Text.ElideRight
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeSmall
                            }
                            Text {
                                text: String(sourceRow.modelData.item_count || 0)
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Left"; onActivated: content.controller.selectDate(new Date(content.controller.selectedDate.getFullYear(), content.controller.selectedDate.getMonth(), content.controller.selectedDate.getDate() - 1)) }
    Shortcut { sequence: "Right"; onActivated: content.controller.selectDate(new Date(content.controller.selectedDate.getFullYear(), content.controller.selectedDate.getMonth(), content.controller.selectedDate.getDate() + 1)) }
    Shortcut { sequence: "PageUp"; onActivated: content.controller.shiftMonth(-1) }
    Shortcut { sequence: "PageDown"; onActivated: content.controller.shiftMonth(1) }
    Shortcut { sequence: "T"; onActivated: content.controller.goToToday() }
    Shortcut { sequence: "F5"; onActivated: content.controller.refresh() }

    Connections {
        target: content.controller
        function onFocusTodoInputRequested() { todoInput.forceActiveFocus(); }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: content.now = new Date()
    }
}
