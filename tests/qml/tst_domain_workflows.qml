pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

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
