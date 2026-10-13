import QtQuick

// Native QML registration/routing coverage without a live compositor binding.
QtObject {
    objectName: "registeredShortcut-" + appid + ":" + name
    property string appid
    property string name
    property string description
    signal pressed()
}
