pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Ui as Ui
import "ColorContrast.js" as Contrast

TestCase {
    id: testCase
    name: "SurfaceOutline"
    when: windowShown
    visible: true
    width: 453
    height: 823

    Component {
        id: clippedSurface
        Item {
            id: viewport
            width: testCase.width
            height: testCase.height
            property real edgeLoss: 0
            clip: true
            Ui.ChooserSurface {
                anchors.fill: null
                x: -viewport.edgeLoss
                y: -viewport.edgeLoss
                width: viewport.width + 2 * viewport.edgeLoss
                height: viewport.height + 2 * viewport.edgeLoss
                color: Ui.Theme.window
            }
        }
    }
    function init(): void { failOnWarning(/.*/); }
    function test_allFourEdgesSurviveClipping_data() {
        // Conservative bound for edge loss when logical window bounds land
        // between physical pixels. Test clipping, not just the item's geometry.
        return [{tag: "normal", loss: 0}, {tag: "edge-quantization", loss: 1}];
    }
    function test_allFourEdgesSurviveClipping(data) {
        const viewport = createTemporaryObject(clippedSurface, testCase, {edgeLoss: data.loss});
        verify(waitForPolish(viewport.Window.window));
        const pixels = grabImage(testCase);
        const scaleX = pixels.width / testCase.width;
        const scaleY = pixels.height / testCase.height;
        const midX = Math.floor(pixels.width / 2), midY = Math.floor(pixels.height / 2);
        const fill = pixels.pixel(midX, midY);
        for (const edge of ["top", "bottom", "left", "right"]) {
            let contrast = 1;
            const horizontal = edge === "top" || edge === "bottom";
            const depth = Math.ceil(3 * (horizontal ? scaleY : scaleX));
            for (let inset = 0; inset < depth; ++inset) {
                const x = horizontal ? midX : edge === "left" ? inset : pixels.width - 1 - inset;
                const y = !horizontal ? midY : edge === "top" ? inset : pixels.height - 1 - inset;
                contrast = Math.max(contrast, Contrast.ratio(pixels.pixel(x, y), fill));
            }
            verify(contrast >= 3, edge + " outline must remain painted inside the visible viewport");
        }
    }
}
