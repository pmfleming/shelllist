import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: tests

    function test_segmentsDoNotBridgeMissingMeasurements(data) {
        if (Screen.devicePixelRatio !== 1) {
            skip("QtTest grabImage crops to logical bounds on high-DPI screens");
            return;
        }
        const plot = createTemporaryObject(plotFactory, tests, {
            isolatedDots: data.isolatedDots
        });
        verify(waitForRendering(plot));
        tryVerify(function () {
            const image = grabImage(plot);
            return image.green(10, 30) < 50 && image.green(90, 30) < 50;
        });
        const image = grabImage(plot);
        compare(image.green(35, 30), 255, "missing data must remain unfilled");
        compare(image.green(65, 10), 255, "separate segments must not be connected");
        verify(data.isolatedDots ? image.green(50, 10) < 50 : image.green(50, 10) > 200);
    }

    function test_segmentsDoNotBridgeMissingMeasurements_data() {
        return [
            {
                tag: "battery-dots",
                isolatedDots: true
            },
            {
                tag: "application-lines",
                isolatedDots: false
            }
        ];
    }

    height: 60
    name: "ChartDrawing"
    visible: true
    when: windowShown
    width: 100

    Component {
        id: plotFactory

        Canvas {
            property bool isolatedDots: true

            height: 60
            width: 100

            onPaint: {
                const context = getContext("2d");
                context.reset();
                context.fillStyle = "white";
                context.fillRect(0, 0, width, height);
                context.fillStyle = "red";
                context.strokeStyle = "red";
                context.lineWidth = 2;
                Ui.ChartDrawing.series(context, [[
                        {
                            x: 2,
                            y: 10
                        },
                        {
                            x: 20,
                            y: 10
                        }
                    ], [], [
                        {
                            x: 50,
                            y: 10
                        }
                    ], [
                        {
                            x: 80,
                            y: 10
                        },
                        {
                            x: 98,
                            y: 10
                        }
                    ]], 50, "red", isolatedDots);
            }
        }
    }
}
