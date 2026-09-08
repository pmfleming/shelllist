import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    name: "DetailsHeader"

    Component {
        id: detailsFactory
        Ui.ActionDetailsPane {
            width: 700
            height: 350
            uiScale: 1
            chooserController: Ui.ChooserController { hasSelection: true }
        }
    }

    function test_aliasDefaultsRemainReactive(): void {
        const pane = createTemporaryObject(detailsFactory, this);
        verify(pane !== null);
        compare(pane.headerHeight, 64);
        compare(pane.titlePixelSize, Ui.Theme.fontSizeTitle);
        pane.uiScale = 2;
        compare(pane.headerHeight, 128);
        compare(pane.titlePixelSize, 2 * Ui.Theme.fontSizeTitle);
        pane.subtitleColor = "red";
        verify(Qt.colorEqual(pane.statusIndicatorColor, "red"));
        pane.statusIndicatorColor = "blue";
        pane.subtitleColor = "green";
        verify(Qt.colorEqual(pane.statusIndicatorColor, "blue"));
        pane.title = "Device";
        compare(pane.title, "Device");
    }
}
