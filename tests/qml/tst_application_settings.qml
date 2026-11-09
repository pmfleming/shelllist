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
            running: false, focused: false, new_workspace: false, autostart: false};
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
    function test_settingsClicksShowInformationInStatusWithoutGrowingRows() {
        const surface = make("code", "3");
        const page = surface.detailsItem;
        const field = form(surface);
        const toggle = findChild(page, "applicationNewWorkspace");
        const card = findChild(page, "applicationDataDetails");
        const information = findChild(page, "applicationSettingsInformation");
        const status = findChild(surface.listItem, "feedbackText").parent;
        verify(waitForRendering(surface));
        verify(toggle.y >= field.y + field.height + Ui.Theme.spacingMd);
        verify(!findChild(field, "formFieldHelp").visible);
        verify(!findChild(card, "sectionHeadingHelp").visible);
        verify(!toggle.showSubtitle);
        compare(information.text, "");
        const originalHeight = field.height;
        const label = findChild(field, "formFieldLabel");
        mouseClick(label, label.width / 2, label.height / 2);
        tryCompare(information, "text", field.helpText);
        verify(status.fullText.includes(field.helpText));
        compare(status.displayText, field.helpText);
        compare(field.height, originalHeight);
        verify(!findChild(field, "formFieldSupport").visible);
        compare(updates().length, 0);

        mouseClick(choice(surface), choice(surface).width / 2, choice(surface).height / 2);
        tryCompare(choice(surface).popup, "visible", true);
        keyClick(Qt.Key_Escape);
        compare(updates().length, 0);

        mouseClick(card, card.width / 2, Ui.Theme.spacingMd);
        tryCompare(information, "text", card.helpText);
        verify(status.fullText.includes("Temporary data is not necessarily safe to delete."));
        setApplication(surface, "code", "3");
        compare(information.text, card.helpText, "Refreshing the same app keeps disclosed context");
        compare(surface.detailsNavigation.availableFields().length, 3);
        mouseClick(toggle, toggle.width - Ui.Theme.spacingLg, toggle.height / 2);
        compare(updates().length, 1);
        compare(updates()[0].params.new_workspace, true);
        tryCompare(information, "text", toggle.subtitle);
        surface.chooserController.handleFailure(surface.chooserController.activeSettingsRequestId, "Permission denied.");
        tryCompare(status, "messageTone", "error");
        setApplication(surface, "shell", "1", "another.desktop");
        tryCompare(information, "text", "");
    }
    function test_appDataCombinesVersionsAndStorageWithoutAddingFields() {
        const surface = make("code", "3");
        const controller = surface.chooserController;
        const app = Object.assign(application("code", "3"), {
            running: true, disk_space_total_bytes: 4096, disk_space_permanent_bytes: 4096, disk_space_temporary_bytes: 0,
            metric_availability: {disk_space_total_bytes: true, disk_space_permanent_bytes: true, disk_space_temporary_bytes: true},
            software: {name: "Example", installations: [{scope: "user:example", package_name: "example-application-with-a-long-package-name",
                active_version: "1.3.1", declared_version: "1.3.0", release: {version: "1.4.0", source: "https://example.test/releases/long/source/description"}}]}
        });
        controller.replaceProviderResults([controller.provider.resultFor(app)], false);
        const card = findChild(surface, "applicationDataDetails");
        verify(card !== null && card.visible);
        compare(card.title, "App data");
        compare(findChild(card, "applicationDataVersions").entries.map(entry => entry.value), ["1.3.1", "1.4.0"]);
        compare(findChild(card, "applicationDataTotal").value, "4.0 KiB");
        compare(findChild(card, "applicationDataStorage").entries.map(entry => entry.value), ["4.0 KiB", "0 B"]);
        const source = findChild(card, "applicationDataSource");
        verify(source.text.includes("user:example"));
        verify(source.text.includes("active 1.3.1"));
        surface.width = 600;
        verify(waitForRendering(surface));
        verify(source.lineCount > 1, "Long package identities wrap in the card");
        const sourcePosition = source.mapToItem(card, 0, 0);
        verify(sourcePosition.x >= 0 && sourcePosition.x + source.width <= card.width);
        const fields = surface.detailsNavigation.availableFields();
        compare(fields.length, 3);
        verify(fields.includes(choice(surface)));
        verify(fields.includes(findChild(surface, "applicationNewWorkspace")));
        verify(fields.includes(findChild(surface, "applicationAutostart")));
        compare(updates().length, 0);
    }
    function test_appDataRetainsUnavailableAndTargetScopedHistory() {
        const surface = make("code", "3");
        const controller = surface.chooserController;
        const card = findChild(surface, "applicationDataDetails");
        const total = findChild(card, "applicationDataTotal");
        compare(total.value, "Unavailable");
        controller.resourceHistory = [{disk_space_total_bytes: 2048, metric_availability: {disk_space_total_bytes: true}}];
        controller.historyTargetId = "different.desktop";
        compare(total.value, "Unavailable");
        controller.historyTargetId = controller.selectedApplication.id;
        compare(total.value, "2.0 KiB");
        compare(findChild(card, "applicationDataStorage").entries[1].value, "Unavailable");
        for (const kind of ["window", "desktop-shortcut"]) {
            const entry = Object.assign(application("", "", kind), {kind: kind});
            controller.replaceProviderResults([controller.provider.resultFor(entry)], false);
            verify(controller.availableDetailsTabs().includes("settings"));
            verify(!findChild(surface, "applicationPreferences").visible);
            compare(surface.detailsNavigation.availableFields().length, 0);
        }
        compare(updates().length, 0);
    }
    function test_newWorkspaceIsIndependentEditableToggle() {
        const surface = make("code", "3");
        const toggle = findChild(surface.detailsItem, "applicationNewWorkspace");
        verify(toggle.visible);
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, toggle);
        compare(updates().length, 0);
        keyClick(Qt.Key_Return);
        compare(updates().length, 1);
        compare(updates()[0].params.new_workspace, true);
        verify(!Object.prototype.hasOwnProperty.call(updates()[0].params, "category"));
        compare(choice(surface).value, "code");
    }
    function test_autostartTraversalAcknowledgementAndRetry() {
        const surface = make("code", "3");
        const controller = surface.chooserController;
        const toggle = findChild(surface, "applicationAutostart");
        keyClick(Qt.Key_Backtab);
        compare(surface.detailsNavigation.currentTarget, toggle);
        compare(updates().length, 0, "Reverse wrap must not toggle");
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, choice(surface));
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, toggle);
        keyClick(Qt.Key_Return);
        compare(updates().length, 1);
        compare(updates()[0].params, {target_id: "example.desktop", autostart: true});
        verify(!toggle.checked, "Submission is not acknowledgement");
        verify(!toggle.interactive);
        keyClick(Qt.Key_Return);
        compare(updates().length, 1);
        const first = controller.activeSettingsRequestId;
        controller.handleFailure(first, "Permission denied.");
        verify(toggle.interactive);
        verify(!toggle.checked);
        compare(choice(surface).errorText, "", "Autostart failure must not mark category invalid");
        verify(controller.settingsFeedback.error.includes("Permission denied"));
        mouseClick(toggle, toggle.width - Ui.Theme.spacingLg, toggle.height / 2);
        compare(updates().length, 2);
        const retry = controller.activeSettingsRequestId;
        controller.applyApplicationSettings(first, {autostart: true});
        compare(controller.activeSettingsRequestId, retry);
        controller.applyApplicationSettings(retry, {autostart: true});
        verify(!toggle.checked, "The refreshed application supplies the saved value");
        const saved = Object.assign(application("code", "3"), {autostart: true});
        controller.replaceProviderResults([controller.provider.resultFor(saved)], false);
        tryCompare(toggle, "checked", true);
        mouseClick(toggle, toggle.width - Ui.Theme.spacingLg, toggle.height / 2);
        compare(updates().length, 3);
        compare(updates()[2].params, {target_id: "example.desktop", autostart: false});
    }
    function test_unavailableAutostartIsNotAnEditableStop() {
        const surface = make("code", "3");
        const controller = surface.chooserController;
        const app = application("code", "3");
        delete app.autostart;
        controller.replaceProviderResults([controller.provider.resultFor(app)], false);
        const toggle = findChild(surface, "applicationAutostart");
        verify(toggle.visible);
        verify(!toggle.interactive);
        compare(surface.detailsNavigation.availableFields().length, 2);
        mouseClick(toggle, toggle.width - Ui.Theme.spacingLg, toggle.height / 2);
        compare(updates().length, 0);
    }
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
