import QtQuick
import "NetworkHealth.js" as Health

// Consumes the daemon's network.health stream. The daemon reports what
// NetworkManager did; deciding what the user sees is this controller's job.
Item {
    required property WifiController controller

    // Most recent transition, whether or not it was worth surfacing.
    property var lastEvent: null
    // Most recent transition that looked like a real failure.
    property var lastFailure: null

    readonly property string lastFailureMessage: lastFailure ? Health.message(lastFailure) : ""

    function clearFailure() { lastFailure = null; }

    function handleEvent(event) {
        if (event.event === "subscribed")
            return;
        lastEvent = event;
        console.info("shelllist nm health " + Health.logLine(event));
        if (!Health.isFailure(event))
            return;
        lastFailure = event;
        // A connect attempt reports its own failure with more context, so a
        // health event about the same attempt would only duplicate it.
        if (controller.connection.running)
            return;
        controller.status = Health.message(event);
    }
}
