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
            id: surface
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
    function test_compositionAndCategoryOnlyOptions() {
        const surface = make("code", "3");
        const control = choice(surface);
        compare(form(surface).label, "Workspace category");
        compare(control.Accessible.name, "Workspace category");
        compare(control.Accessible.description, "Editors and development tools");
        compare(control.options.map(option => option.label), ["Shell", "Browser", "Code", "Media", "Text"]);
        compare(control.contentItem.text, "Code");
        compare(findChild(control, "dropDownValueIcon").symbol, "code");
        verify(findChild(surface.detailsItem, "applicationCategoryEffect").informationOnly);
        compare(surface.detailsNavigation.targets.length, 2, "only the editor and read-only page fallback are discovered");
        verify(findChild(control, "browseFocusIndicator").visible);
        open(surface);
        verify(!findChild(control, "browseFocusIndicator").visible);
        const symbols = ["terminal", "language", "code", "music_note", "description"];
        for (let i = 0; i < 5; i++) {
            const row = findChild(control.popup.contentItem, "dropDownOption-" + i);
            verify(row !== null);
            compare(row.Accessible.name, control.options[i].label);
            compare(findChild(row, "dropDownOptionIcon").symbol, symbols[i]);
            compare(findChild(row, "dropDownSelectedCheck").visible, i === 2);
        }
        keyClick(Qt.Key_End);
        compare(control.highlightedIndex, 4);
        verify(findChild(findChild(control.popup.contentItem, "dropDownOption-2"), "dropDownSelectedCheck").visible,
            "native highlighting is not acknowledgement");
        compare(updates().length, 0);
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        verify(!control.popup.visible);
        compare(control.contentItem.text, "Code");
        compare(updates().length, 0);
    }
    function test_emptyAndMismatchedMapping_data() {
        return [
            {tag: "unassigned", category: "", workspace: "", mismatch: false},
            {tag: "inferred-not-saved", category: "code", workspace: "", mismatch: false},
            {tag: "mismatch", category: "code", workspace: "2", mismatch: true},
            {tag: "unknown-category", category: "unknown", workspace: "3", mismatch: true}
        ];
    }
    function test_emptyAndMismatchedMapping(data) {
        const surface = make(data.category, data.workspace);
        compare(choice(surface).value, "");
        compare(choice(surface).contentItem.text, "Choose a category");
        compare(surface.detailsItem.mappingNeedsAttention, data.mismatch);
        compare(form(surface).message, data.mismatch
            ? "Category mapping needs attention. Choose a category to update it." : "No workspace category assigned.");
        verify(findChild(surface.detailsItem, "applicationCategoryConsequence").text !== "New windows open in this category’s workspace.");
        compare(updates().length, 0);
    }
    function test_saveKeepsAcknowledgement_data() {
        return [
            {tag: "enter", key: Qt.Key_Return, modifiers: Qt.NoModifier},
            {tag: "tab", key: Qt.Key_Tab, modifiers: Qt.NoModifier},
            {tag: "shift-tab", key: Qt.Key_Tab, modifiers: Qt.ShiftModifier}
        ];
    }
    function test_saveKeepsAcknowledgement(data) {
        const surface = make("shell", "1");
        const controller = surface.chooserController;
        const control = choice(surface);
        open(surface);
        keyClick(Qt.Key_Down);
        compare(updates().length, 0);
        keyClick(data.key, data.modifiers);
        compare(updates().length, 1);
        compare(updates()[0].params, {target_id: "example.desktop", category: "browser"});
        compare(control.value, "shell");
        compare(control.contentItem.text, "Shell");
        verify(controller.settingsInFlight);
        verify(!control.enabled);
        verify(form(surface).message.indexOf("Saving Browser") === 0);
        verify(surface.detailsNavigation.browsing, "pending control is unavailable; Tab uses the page fallback");
        control.activated(4);
        compare(updates().length, 1, "busy controls cannot submit late activation");
        controller.applyApplicationSettings(controller.activeSettingsRequestId, {category: "browser", workspace_id: "2"});
        verify(!controller.settingsInFlight);
        verify(control.enabled);
        compare(control.value, "shell", "catalog refresh remains the authoritative source binding");
        setApplication(surface, "browser", "2");
        compare(control.contentItem.text, "Browser");
        compare(form(surface).message, "Web and network applications");
    }
    function test_singleFieldWrapAndDiscardOnExit() {
        const surface = make("shell", "1");
        const control = choice(surface);
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, control);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget, control);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Tab);
        verify(surface.detailsNavigation.editing);
        compare(surface.detailsNavigation.currentTarget, control);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(surface.detailsNavigation.editing);
        compare(updates().length, 0, "no-op wrapping does not submit");
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_End);
        surface.detailsNavigation.suspendView();
        verify(!control.popup.visible);
        verify(!control.editSession.active);
        compare(control.contentItem.text, "Shell");
        compare(updates().length, 0, "leaving discards the menu's uncommitted choice");
    }
    function test_pointerChoiceRemainsLocalAndSavedCheckDoesNotFollowDraft() {
        const surface = make("shell", "1");
        const control = choice(surface);
        mouseClick(control, control.width / 2, control.height / 2);
        tryCompare(control.popup, "visible", true);
        verify(surface.detailsNavigation.editing);
        const textOption = findChild(control.popup.contentItem, "dropDownOption-4");
        mouseClick(textOption, textOption.width / 2, textOption.height / 2);
        tryCompare(control.popup, "visible", false);
        compare(control.contentItem.text, "Text");
        compare(control.value, "shell");
        compare(updates().length, 0);
        keyClick(Qt.Key_Space);
        tryCompare(control.popup, "visible", true);
        verify(findChild(findChild(control.popup.contentItem, "dropDownOption-0"), "dropDownSelectedCheck").visible);
        verify(!findChild(findChild(control.popup.contentItem, "dropDownOption-4"), "dropDownSelectedCheck").visible);
        keyClick(Qt.Key_Escape);
        compare(control.contentItem.text, "Shell");
        compare(updates().length, 0);
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
        compare(form(surface).message, "Web and network applications");
    }
}
