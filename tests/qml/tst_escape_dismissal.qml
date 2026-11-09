pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: tests
    name: "EscapeDismissal"
    when: windowShown
    visible: true
    width: 600
    height: 500
    property int escapedReleases: 0
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Escape)
            escapedReleases++;
    }

    Component {
        id: otherWindowFactory
        Window { width: 200; height: 100; visible: true; transientParent: null }
    }

    Component {
        id: factory
        Ui.VisualSurface {
            id: host
            contentWidth: tests.width
            loadWhen: visible
            property int dismissals: 0
            property int deferred: 0
            property alias controller: controller
            onDismissalDeferred: {
                deferred++;
                controller.prepareUiDeactivation();
            }
            onDismissalReady: {
                dismissals++;
                controller.deactivateUi();
                visible = false;
            }
            Ui.ChooserController {
                id: controller
                uiActive: true
                onCloseWindowRequested: host.requestDismissal()
            }
            content: Component {
                Ui.PanelSurface {
                    chooserController: controller
                    Ui.TextField {
                        objectName: "editor"
                        width: 200
                        text: "original"
                    }
                }
            }
        }
    }
    function init(): void { failOnWarning(/.*/); }
    function make() {
        tests.Window.window.requestActivate();
        tryCompare(tests.Window.window, "active", true);
        const host = createTemporaryObject(factory, tests);
        verify(host !== null);
        tryVerify(() => findChild(host, "editor") !== null);
        wait(0);
        return host;
    }
    function test_standaloneDiscardThenCloseOnRelease(): void {
        const host = make();
        const editor = findChild(host, "editor");
        editor.focusInput(false);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        compare(editor.text, "originalx");
        keyClick(Qt.Key_Escape);
        compare(editor.text, "original");
        compare(host.dismissals, 0);
        verify(!host.escapeDown, "editor cancellation releases Escape without closing");

        keyPress(Qt.Key_Escape);
        verify(host.dismissalPending);
        verify(host.visible);
        compare(host.deferred, 1);
        compare(host.dismissals, 0);
        // Further presses must not invoke window-wide shortcuts while pending.
        keyPress(Qt.Key_Escape);
        compare(host.deferred, 1);
        compare(host.dismissals, 0);
        const releases = escapedReleases;
        keyRelease(Qt.Key_Escape);
        compare(host.dismissals, 1);
        compare(escapedReleases, releases, "closing key-up must be accepted before hiding");
        verify(!host.visible);
    }
    function test_nonKeyboardCloseIsImmediate(): void {
        const host = make();
        host.controller.closeWindowRequested();
        compare(host.dismissals, 1);
        compare(host.deferred, 0);
    }
    function test_externalHideCancelsPendingRelease(): void {
        const host = make();
        keyPress(Qt.Key_Escape);
        verify(host.dismissalPending);
        host.visible = false;
        verify(!host.dismissalPending);
        verify(!host.escapeDown);
        keyRelease(Qt.Key_Escape);
        compare(host.dismissals, 0);
        host.visible = true;
        host.controller.activateUi("");
        wait(0);
        host.controller.closeWindowRequested();
        compare(host.dismissals, 1, "a new invocation must not wait for an old release");
    }
    function test_focusLossFinishesAnAlreadyPendingClose(): void {
        const host = make();
        keyPress(Qt.Key_Escape);
        verify(host.dismissalPending);
        const other = createTemporaryObject(otherWindowFactory, tests);
        verify(other !== null);
        other.requestActivate();
        tryCompare(other, "active", true);
        compare(host.Window.window.active, false);
        tryCompare(host, "dismissals", 1);
        verify(!host.dismissalPending);
        verify(!host.escapeDown);
        keyRelease(Qt.Key_Escape);
        compare(host.dismissals, 1);
        other.close();
        tests.Window.window.requestActivate();
        tryCompare(tests.Window.window, "active", true);
    }
}
