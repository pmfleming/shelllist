import QtQuick

LabeledValueSlider {
    from: 0
    to: 100
    stepSize: 1
    valueText: qsTr("%1%").arg(Math.round(value))
}
