pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: content

    required property SurfaceRegistry registry

    function bundle(surfaceId: string): SurfaceBundle {
        return registry.bundleFor(surfaceId);
    }

    Repeater {
        model: content.registry.descriptors

        delegate: Loader {
            required property var modelData
            readonly property SurfaceBundle bundle: content.bundle(modelData.id)

            anchors.fill: parent
            active: bundle !== null && content.registry.wasOpened(modelData.id)
            visible: content.registry.currentId === modelData.id
            sourceComponent: bundle ? bundle.content : null
        }
    }
}
