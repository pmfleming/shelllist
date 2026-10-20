import QtQuick
import "NetworkHealth.js" as Health

// nm-daemon owns failure classification and cross-source correlation. This
// controller owns only the status-line presentation and duplicate UI feedback.
Item {
    required property WifiController controller

    property string lastNotificationKey: ""
    property double lastNotificationAtMs: 0
    readonly property int notificationDeduplicationMs: 3000

    function handleEvent(event) {
        if (event.event === "subscribed")
            return;
        console.info("shelllist nm health " + Health.logLine(event));
        if (!Health.isFailure(event))
            return;
        // A connect attempt reports its own failure with more context, so a
        // health event about the same attempt would only duplicate it.
        if (controller.connection.running)
            return;
        const key = Health.notificationKey(event);
        const now = Date.now();
        if (Health.isDuplicateNotification(event, lastNotificationKey, lastNotificationAtMs, now, notificationDeduplicationMs))
            return;
        lastNotificationKey = key;
        lastNotificationAtMs = now;
        controller.status = Health.message(event);
    }
}
