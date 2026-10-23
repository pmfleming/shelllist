import QtQuick

// nm-daemon owns classification, connection-outcome suppression and duplicate
// feedback. The view renders only the native recommendation and native message.
Item {
    required property WifiController controller

    function handleEvent(event) {
        if (event.event === "subscribed")
            return;
        const health = event.data?.health;
        if (health?.notification_recommended === true && typeof health.message === "string" && health.message.length > 0)
            controller.status = health.message;
    }
}
