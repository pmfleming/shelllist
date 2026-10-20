pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Shelllist.Launcher as Apps

// QtTest supplies native input/assertions, but Quickshell must own the engine:
// its Process plugin is statically linked and unavailable to qmltestrunner.
// The Python test invokes this journey explicitly and requires the PASS marker.
ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1100
        implicitHeight: 800
        Apps.ApplicationContent {
            id: panel
            anchors.fill: parent
            controller: Apps.ApplicationController {
                id: controller
                property int dismissals: 0
                onCloseWindowRequested: dismissals++
            }
        }
        Process {
            id: repair
            property int result: -1
            command: ["fixture-settings-repair"]
            // Quickshell's qmltypes omit QProcess::ExitStatus (as in the production bridge).
            onExited: function(code) { result = code; } // qmllint disable signal-handler-parameters
        }
        TestCase {
            id: driver
            name: "ApplicationJourney"
            when: false
            property string stage: "catalog"
            function runJourney() {
                controller.activateUi("1");
                tryVerify(() => controller.filteredResults.length === 2, 15000);
                stage = "search";
                panel.listItem.focusSearch();
                for (const letter of "Journey") keyClick(letter);
                tryCompare(controller, "filterText", "Journey");
                tryVerify(() => controller.filteredResults.length === 1);
                compare(controller.selectedApplication.id, "journey.desktop");
                panel.listItem.focusList();
                keyClick(Qt.Key_Right);
                tryCompare(controller, "detailsOpen", true);
                // Traverse the real panel's tabs, not an injected settings page.
                keyClick(Qt.Key_Tab, Qt.ControlModifier);
                keyClick(Qt.Key_Tab, Qt.ControlModifier);
                tryCompare(controller, "detailsTab", "settings");
                tryVerify(() => panel.detailsNavigation.contentReady);
                let category;
                tryVerify(() => {
                    category = findChild(panel, "applicationCategory");
                    return category !== null && category.visible && category.width > 0 && category.height > 0;
                });
                stage = "settings failure";
                const original = category.value;
                chooseText(category);
                compare(category.value, original, "sending is not acknowledgement");
                tryVerify(() => !controller.settingsInFlight && category.errorText.length > 0, 10000);
                compare(category.value, original, "failed save cannot publish the requested category");
                verify(category.enabled, "a rejected save remains retryable");
                repair.running = true;
                tryCompare(repair, "result", 0);
                stage = "settings retry";
                chooseText(category);
                tryVerify(() => !controller.settingsInFlight && controller.selectedApplication.category === "text", 10000);
                compare(category.value, "text");
                compare(category.errorText, "");
                panel.listItem.focusList();
                keyClick(Qt.Key_F5);
                tryVerify(() => !controller.refreshInFlight && controller.selectedApplication.category === "text");
                stage = "failed launch";
                keyClick(Qt.Key_Return, Qt.ShiftModifier);
                tryVerify(() => !controller.actionInFlight && controller.selectedActionMessage.includes("fixture launch rejected"), 15000);
                compare(controller.dismissals, 0, "failed launch must not hand off the UI");
                wait(250);
                compare(controller.dismissals, 0, "failure must not automatically retry");
                stage = "explicit launch retry";
                keyClick(Qt.Key_Return, Qt.ShiftModifier);
                tryCompare(controller, "dismissals", 1, 15000);
                tryVerify(() => !controller.actionInFlight, 15000);
                compare(controller.selectedApplication.category, "text");
            }
            function chooseText(category) {
                mouseClick(category, category.width / 2, category.height / 2);
                tryCompare(category.popup, "visible", true);
                const index = category.options.findIndex(option => option.value === "text");
                verify(index >= 0);
                const option = findChild(category.popup.contentItem, "dropDownOption-" + index);
                verify(option !== null);
                mouseClick(option, option.width / 2, option.height / 2);
            }
        }
        Timer {
            interval: 100
            running: true
            onTriggered: {
                try {
                    driver.runJourney();
                    console.log("SHELLLIST_E2E_PASS application");
                    Qt.quit();
                } catch (error) {
                    console.error("SHELLLIST_E2E_FAIL application at " + driver.stage + ": " + error);
                    Qt.exit(1);
                }
            }
        }
    }
}
