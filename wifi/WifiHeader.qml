import QtQuick
import QtQuick.Layouts

RowLayout {
    id: header

    property string filterText: ""

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal refreshRequested

    Layout.fillWidth: false
    Layout.preferredWidth: 425
    Layout.maximumWidth: 425
    Layout.preferredHeight: 46
    spacing: 12

    function focusSearch() {
        search.forceActiveFocus();
    }

    Rectangle {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 10
        Layout.alignment: Qt.AlignVCenter
        color: "#15335f"
        Text {
            anchors.centerIn: parent
            text: "󰤨"
            color: "#7dd3fc"
            font.pixelSize: 18
        }
    }

    TextInput {
        id: search
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignVCenter
        focus: true
        leftPadding: 38
        rightPadding: 12
        color: "#dbeafe"
        selectionColor: "#2563eb"
        selectedTextColor: "white"
        font.pixelSize: 15
        verticalAlignment: TextInput.AlignVCenter
        text: header.filterText
        onTextChanged: header.filterEdited(text)
        Keys.onPressed: function (event) {
            header.keyPressed(event);
        }

        Text {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "⌕"
            color: "#64748b"
            font.pixelSize: 22
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#111827"
            border.color: "#233247"
            z: -1
        }
    }

    Rectangle {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 8
        Layout.alignment: Qt.AlignVCenter
        color: "transparent"
        border.color: "#233247"
        Text {
            anchors.centerIn: parent
            text: "↻"
            color: "#94a3b8"
            font.pixelSize: 20
        }
        MouseArea {
            anchors.fill: parent
            onClicked: header.refreshRequested()
        }
    }
}
