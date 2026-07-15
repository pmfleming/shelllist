import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: choice

    property var options: []
    property string value: ""
    property bool interactive: true

    signal selected(string value)

    readonly property int currentIndex: {
        for (let index = 0; index < options.length; ++index)
            if (options[index].value === value)
                return index;
        return 0;
    }
    readonly property string currentLabel: options.length > 0
        ? (options[currentIndex].label || options[currentIndex].value || "")
        : ""

    implicitHeight: 38
    radius: Theme.controlRadius
    color: Theme.input
    border.color: Theme.border
    opacity: interactive ? 1.0 : 0.55

    function chooseNext() {
        if (!interactive || options.length === 0)
            return;
        const next = (currentIndex + 1) % options.length;
        selected(options[next].value);
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: choice.currentLabel
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            text: "󰅀"
            color: Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: 14
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: choice.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: choice.chooseNext()
    }
}
