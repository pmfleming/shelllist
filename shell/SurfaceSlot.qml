import QtQuick

// Lazily loads one surface's SurfaceBundle once the registry marks it loaded.
Loader {
    required property string surfaceId
    required property SurfaceRegistry owner
    readonly property SurfaceBundle bundle: item as SurfaceBundle

    active: owner.isLoaded(surfaceId)
    asynchronous: true
    onLoaded: owner.notifySurfaceReady(surfaceId)
}
