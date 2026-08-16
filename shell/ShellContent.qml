pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: content

    required property SurfaceRegistry registry

    function bundle(surfaceId: string): SurfaceBundle {
        return registry.bundleFor(surfaceId);
    }

    function shouldLoadView(bundle: SurfaceBundle, surfaceId: string): bool {
        if (!bundle)
            return false;
        if (bundle.viewLoadPolicy === "eager")
            return true;
        if (bundle.viewLoadPolicy === "on-demand")
            return registry.wasOpened(surfaceId) && registry.currentId === surfaceId;
        return registry.wasOpened(surfaceId);
    }

    Repeater {
        model: content.registry.descriptors

        delegate: Loader {
            id: surfaceLoader

            required property var modelData
            readonly property SurfaceBundle bundle: content.bundle(modelData.id)

            anchors.fill: parent
            active: content.shouldLoadView(bundle, modelData.id)
            visible: content.registry.currentId === modelData.id
            sourceComponent: bundle ? bundle.content : null
        }
    }
}
