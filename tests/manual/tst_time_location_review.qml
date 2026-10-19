import QtQuick
import Quickshell

// Reuse the actual consumer suite and its recording transport for opt-in captures.
// Run via run-qmlquality-tests.sh after creating target/time-location-review/.
Item {
    width: 1100
    height: 700
    Component.onCompleted: {
        Quickshell.environment = Object.assign({}, Quickshell.environment, {
            SHELLLIST_TIME_REVIEW_DIR: decodeURIComponent(Qt.resolvedUrl("../../target/time-location-review/").toString().replace(/^file:\/\//, ""))
        });
        fixture.active = true;
    }
    Loader {
        id: fixture
        active: false
        source: "../qml/tst_time_weather_locations.qml"
    }
}
