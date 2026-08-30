import QtQuick
import "WeatherVisuals.js" as Visuals

Image {
    id: icon

    property int conditionCode: -1
    property bool daytime: true
    property string description: ""

    source: Qt.resolvedUrl("assets/weather/"
        + Visuals.iconName(conditionCode, daytime) + ".svg")
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    asynchronous: true
    Accessible.role: Accessible.Graphic
    Accessible.name: description.length > 0 ? description : "Weather condition"
}
