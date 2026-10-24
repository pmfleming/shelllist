pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core

DaemonTestCase {
    id: testCase
    name: "DomainWorkflows"
    when: windowShown
    visible: true
    width: 1100
    height: 650
    Component {
        id: panelFactory
        Ui.PanelSurface {
            chooserController: Ui.ChooserController {
                id: owner
                uiActive: true
                viewMemory: Ui.ChooserMemory {
                    controller: owner
                    key: "settings::test"
                    tab: "settings"
                    tabs: ["settings"]
                    presentationOpen: true
                }
            }
            Ui.DetailFlickable {
                anchors.fill: parent
                viewMemory: owner.viewMemory
                memoryTab: "settings"
                Ui.TextField { objectName: "ordinary"; width: parent.width; text: "ordinary value" }
            }
        }
    }
    Component {
        id: registryFactory
        Core.ProviderRegistry {
            id: registry
            property string rejection: ""
            property int calls: 0
            onActionRejected: function (error) { rejection = error.code; }
            Core.Provider {
                providerId: "test"
                displayName: "Test"
                function execute(request: var): bool { registry.calls++; return false; }
            }
        }
    }
    function test_providerDispatchFailsClosed() {
        const registry = createTemporaryObject(registryFactory, testCase);
        compare(registry.providerById("absent"), null);
        verify(!registry.execute(null, "", {}));
        compare(registry.rejection, "missing-result");
        const provider = registry.providerById("test");
        const result = provider.makeResult({id: "one", title: "One", actions: [Core.Model.keepOpenAction("open", "Open", {})]});
        provider.providerEnabled = false;
        verify(!registry.execute(result, "open", {}));
        compare(registry.rejection, "provider-unavailable");
        compare(registry.calls, 0);
        provider.providerEnabled = true;
        verify(!registry.execute(result, "open", {}));
        compare(registry.rejection, "provider-rejected");
        compare(registry.calls, 1);
    }
    function init() { failOnWarning(/.*/); }
    Component {
        id: iconActionFactory
        Ui.ActionButton { label: "Settings"; icon: "󰒓"; width: 42; height: 42 }
    }
    function test_revealedSensitiveFieldsNeverHaveRestorableLocations() {
        const panel = createTemporaryObject(panelFactory, testCase);
        const field = findChild(panel, "ordinary");
        compare(Ui.FocusLocations.key(null), "");
        compare(Ui.FocusLocations.uniqueTarget([field], field.focusKey), field);
        const duplicate = createTemporaryObject(iconActionFactory, panel, {objectName: field.objectName, enabled: false});
        compare(Ui.FocusLocations.uniqueTarget([field, duplicate], field.focusKey), null);
        field.sensitive = true;
        field.password = false;
        compare(Ui.FocusLocations.uniqueTarget([field], field.focusKey), null);
        field.focusInput(false);
        compare(field.selectionState(), null);
        compare(Ui.FocusLocations.capture(panel, findChild(field, "fieldInput")), null);
        panel.detailsNavigation.currentTarget = field;
        compare(panel.detailsNavigation.locationState().target, "");
    }
}
