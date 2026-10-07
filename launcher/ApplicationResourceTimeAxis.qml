pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

RowLayout {
    id: axis
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds

    function timeLabel(index: int): string {
        const timestamp = rangeStartMilliseconds + (rangeEndMilliseconds - rangeStartMilliseconds) * index / 2;
        return isFinite(timestamp) && timestamp > 0 ? Qt.formatTime(new Date(timestamp), "HH:mm") : "--:--";
    }
    Repeater {
        model: 3
        delegate: Ui.ThemeText {
            required property int index
            Layout.fillWidth: true
            text: axis.timeLabel(index)
            horizontalAlignment: index === 0 ? Text.AlignLeft : index === 2 ? Text.AlignRight : Text.AlignHCenter
            font.pixelSize: Ui.Theme.fontSizeCaption
            color: Ui.Theme.mutedText
        }
    }
}
