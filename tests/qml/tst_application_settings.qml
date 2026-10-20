pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "../../launcher" as Apps

DaemonTestCase {
    id: tests
    name: "ApplicationSettings"
    when: windowShown
    visible: true
    width: 900
    height: 650

    Component {
        id: factory
        Ui.ProviderChooserSurface {
            width: tests.width
            height: tests.height
            chooserController: Apps.ApplicationController {
                id: controller
                uiActive: true
                detailsTab: "settings"
            }
            listComponent: Ui.ChooserListPane {
                chooserController: controller
                powerVisible: false
                resultModel: controller.filteredResults
                rowDelegate: Rectangle { implicitWidth: 300; implicitHeight: 48 }
            }
            detailsComponent: Apps.ApplicationSettingsPage {
                controller: controller
                application: controller.selectedApplication || ({})
            }
        }
    }

    function init() {
        failOnWarning(/.*/);
        calls = [];
        clientReady = true;
    }
    function application(category, workspace, id) {
        return {id: id || "example.desktop", name: "Example", kind: "desktop-application",
            category: category, default_workspace_id: workspace, instances: [], desktop_actions: [],
            running: false, focused: false};
    }
    function setApplication(surface, category, workspace, id) {
        const controller = surface.chooserController;
        controller.replaceProviderResults([controller.provider.resultFor(application(category, workspace, id))], false);
    }
    function make(category, workspace) {
        const surface = createTemporaryObject(factory, tests);
        verify(surface !== null);
        setApplication(surface, category, workspace);
        surface.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null);
        keyClick(Qt.Key_Tab);
        tryVerify(() => surface.detailsNavigation.browsing);
        tryCompare(surface.detailsNavigation, "currentTarget", choice(surface));
        return surface;
    }
    function choice(surface) { return findChild(surface.detailsItem, "applicationCategory"); }
    function form(surface) { return findChild(surface.detailsItem, "applicationCategoryField"); }
    function updates() { return calls.filter(call => call.method === "applications.settings.update"); }
    function open(surface) {
        keyClick(Qt.Key_Return);
        verify(surface.detailsNavigation.editing);
        keyClick(Qt.Key_Space);
        tryCompare(choice(surface).popup, "visible", true);
    }
    function test_failureRetryAndTargetScopedFeedback() {
        const surface = make("shell", "1");
        const controller = surface.chooserController;
        open(surface);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        const first = controller.activeSettingsRequestId;
        controller.handleFailure("settings-obsolete", "Obsolete failure");
        verify(controller.settingsInFlight);
        compare(choice(surface).errorText, "");
        controller.handleFailure(first, "Permission denied.");
        verify(!controller.settingsInFlight);
        compare(choice(surface).value, "shell");
        verify(form(surface).message.indexOf("Couldn’t save Browser.") === 0);
        verify(form(surface).message.indexOf("Permission denied.") >= 0);
        verify(findChild(choice(surface), "dropDownErrorIcon").visible);
        verify(choice(surface).Accessible.description.indexOf("Choose again to retry") >= 0);
        setApplication(surface, "code", "3", "another.desktop");
        compare(choice(surface).errorText, "", "failure belongs to the originating application");
        setApplication(surface, "shell", "1");
        wait(0); // Allow keyed page-memory restoration before fresh input.
        surface.detailsNavigation.focusContent();
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, choice(surface));
        open(surface);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(updates().length, 2);
        const retry = controller.activeSettingsRequestId;
        verify(retry !== first);
        compare(choice(surface).errorText, "");
        controller.handleFailure(first, "Late failure");
        compare(controller.activeSettingsRequestId, retry);
        controller.applyApplicationSettings(first, {category: "text", workspace_id: "5"});
        compare(controller.activeSettingsRequestId, retry);
        controller.applyApplicationSettings(retry, {category: "browser", workspace_id: "2"});
        setApplication(surface, "browser", "2");
        compare(choice(surface).value, "browser");
        compare(form(surface).message, "");
        compare(form(surface).supportingText, "Web and network applications");
    }
}
