import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "ImageAssets"
    when: windowShown

    Component {
        id: imageComponent
        Image {
            width: 64
            height: 64
            asynchronous: true
        }
    }

    function init() {
        failOnWarning(/.*(?:Error decoding|Unsupported image format).*/);
    }

    function test_svgAssets_data() {
        return [
            {
                tag: "weather",
                source: Qt.resolvedUrl("../../qml/Shelllist/Activity/assets/weather/clear-day.svg")
            },
            {
                tag: "timezones",
                source: Qt.resolvedUrl("../../qml/Shelllist/Activity/assets/timezones/world-time-zones.svg")
            }
        ];
    }

    function test_svgAssets(data) {
        const image = createTemporaryObject(imageComponent, testCase, {
            source: data.source
        });
        verify(image !== null);
        tryCompare(image, "status", Image.Ready);
        verify(image.sourceSize.width > 0 && image.sourceSize.height > 0);
    }
}
