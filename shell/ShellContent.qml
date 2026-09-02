pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Item {
    id: content

    required property SurfaceRegistry registry
    property var readySurfaces: ({})
    readonly property bool currentSurfaceReady:
        readySurfaces[registry.currentId] === true

    function markSurfaceReady(surfaceId: string): void {
        const next = Object.assign({}, readySurfaces);
        next[surfaceId] = true;
        readySurfaces = next;
    }

    function bundle(surfaceId: string): SurfaceBundle {
        return registry.bundleFor(surfaceId);
    }

    Rectangle {
        anchors.fill: parent
        color: Ui.Theme.window
        visible: !content.currentSurfaceReady

        Ui.PulsingLabel {
            anchors.centerIn: parent
            text: "Loading " + (content.registry.currentBundle
                ? content.registry.currentBundle.displayName : "surface") + "…"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }
    }

    Repeater {
        model: content.registry.descriptors

        delegate: Loader {
            required property var modelData
            readonly property SurfaceBundle bundle: content.bundle(modelData.id)

            anchors.fill: parent
            active: bundle !== null && content.registry.wasOpened(modelData.id)
            visible: content.registry.currentId === modelData.id
            asynchronous: true
            sourceComponent: bundle ? bundle.content : null
            onLoaded: {
                content.markSurfaceReady(modelData.id);
                if (bundle && content.registry.currentId === modelData.id)
                    Qt.callLater(bundle.controller.focusSearchRequested);
            }
        }
    }
}
